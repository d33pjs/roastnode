require "ipaddr"
require "set"

class InstanceBackupArchiveValidator
  CUPPING_REQUEST_KEYS = %w[
    id workspace_id brew_id token token_digest snapshot feedback_comment opened_at feedback_expires_at closed_at
    last_guest_ip expiration_job_enqueued_at expiration_job_enqueueing_at created_at updated_at
  ].freeze
  MEDIA_FILE_KEYS = %w[
    path record_type record_id attachment_id attachment_name filename content_type byte_size checksum created_at
  ].freeze
  MANIFEST_MEDIA_FILE_KEYS = (MEDIA_FILE_KEYS + [ "sha256" ]).freeze

  Result = Struct.new(:errors, :manifest, :payload, :media_files, keyword_init: true) do
    def valid?
      errors.empty?
    end
  end

  def self.archive_bytes_for(source)
    return source.read if source.respond_to?(:read)
    return File.binread(source) if source.is_a?(Pathname)
    return File.binread(source) if file_path_string?(source)

    source.to_s
  end

  def self.file_path_string?(source)
    source.is_a?(String) && !source.include?("\0") && File.file?(source)
  end

  def initialize(archive_source)
    @archive_bytes = self.class.archive_bytes_for(archive_source)
  end

  def call
    errors = []
    manifest = {}
    payload = {}
    media_files = []

    Zip::File.open_buffer(archive_bytes) do |zip|
      manifest = read_json_entry(zip, "manifest.json", errors)
      validate_manifest(manifest, errors)
      media_files = manifest["files"].is_a?(Array) ? manifest["files"] : []

      data_path = manifest.dig("data", "path")
      payload = read_json_entry(zip, data_path, errors) if data_path.present?
      validate_payload(payload, media_files, errors)

      validate_media_files(zip, media_files, errors)
    end
  rescue Zip::Error, JSON::ParserError, KeyError => error
    errors << error.message
  ensure
    return Result.new(errors:, manifest:, payload:, media_files:)
  end

  private
    attr_reader :archive_bytes

    def read_json_entry(zip, path, errors)
      if path.blank?
        errors << "Archive manifest does not name a data entry."
        return {}
      end

      entry = zip.find_entry(path)
      unless entry
        errors << "Archive is missing #{path}."
        return {}
      end

      JSON.parse(entry.get_input_stream.read)
    end

    def validate_manifest(manifest, errors)
      unless manifest["format"] == InstanceBackupArchiveBuilder::FORMAT
        errors << "Archive format is not #{InstanceBackupArchiveBuilder::FORMAT}."
      end
      unless manifest["version"] == InstanceBackupArchiveBuilder::VERSION
        errors << "Archive version is not #{InstanceBackupArchiveBuilder::VERSION}."
      end
    end

    def validate_payload(payload, manifest_media_files, errors)
      unless payload["format"] == InstanceReadableExportBuilder::FORMAT
        errors << "Readable export format is not #{InstanceReadableExportBuilder::FORMAT}."
      end
      unless payload["version"] == InstanceReadableExportBuilder::VERSION
        errors << "Readable export version is not #{InstanceReadableExportBuilder::VERSION}."
      end
      errors << "Archive media catalogs do not match." unless valid_media_catalogs?(payload["media_files"], manifest_media_files)
      errors << "Archive contains an invalid cupping request." unless valid_cupping_requests?(payload, manifest_media_files:)
    end

    def valid_media_catalogs?(payload_files, manifest_files)
      return false unless payload_files.is_a?(Array) && manifest_files.is_a?(Array)
      return false unless payload_files.all? { |file| valid_media_catalog_row?(file, MEDIA_FILE_KEYS) }
      return false unless manifest_files.all? { |file| valid_media_catalog_row?(file, MANIFEST_MEDIA_FILE_KEYS) }

      payload_by_id = unique_media_catalog(payload_files)
      manifest_by_id = unique_media_catalog(manifest_files)
      return false unless payload_by_id && manifest_by_id && payload_by_id.keys.to_set == manifest_by_id.keys.to_set

      payload_by_id.all? do |attachment_id, file|
        file == manifest_by_id.fetch(attachment_id).except("sha256")
      end
    end

    def valid_media_catalog_row?(file, expected_keys)
      exact_hash?(file, expected_keys) &&
        valid_string?(file["path"], present: true, maximum: 1_000) &&
        valid_string?(file["record_type"], present: true, maximum: 100) &&
        file["record_id"].is_a?(Integer) &&
        file["attachment_id"].is_a?(Integer) &&
        valid_string?(file["attachment_name"], present: true, maximum: 100) &&
        valid_string?(file["filename"], present: true, maximum: 1_000) &&
        valid_nullable_string?(file["content_type"]) &&
        file["byte_size"].is_a?(Integer) && file["byte_size"] >= 0 &&
        valid_nullable_string?(file["checksum"]) &&
        valid_archived_time_string?(file["created_at"]) &&
        (!file.key?("sha256") || file["sha256"].is_a?(String) && file["sha256"].match?(/\A[0-9a-f]{64}\z/))
    end

    def unique_media_catalog(files)
      by_id = files.index_by { |file| file["attachment_id"] }
      paths = files.map { |file| file["path"] }
      return if by_id.length != files.length || paths.uniq.length != paths.length

      by_id
    end

    def valid_cupping_requests?(payload, manifest_media_files:)
      seen_ids = Set.new
      seen_brew_ids = Set.new
      seen_tokens = Set.new
      seen_digests = Set.new

      Array(payload["workspaces"]).all? do |workspace_payload|
        requests = workspace_payload["cupping_requests"]
        next true if requests.nil?
        next false unless requests.is_a?(Array)

        workspace_id = workspace_payload.dig("workspace", "id")
        brews = Array(workspace_payload["brews"]).index_by { |row| row["id"] }
        requests.all? do |row|
          valid_cupping_request_row?(
            row, workspace_id:, brews:, media_files: manifest_media_files,
            seen_ids:, seen_brew_ids:, seen_tokens:, seen_digests:
          )
        end
      end
    end

    def valid_cupping_request_row?(row, workspace_id:, brews:, media_files:, seen_ids:, seen_brew_ids:, seen_tokens:, seen_digests:)
      return false unless exact_hash?(row, CUPPING_REQUEST_KEYS)

      id = row["id"]
      brew_id = row["brew_id"]
      token = row["token"]
      digest = row["token_digest"]
      brew = brews[brew_id]
      return false unless id.is_a?(Integer) && brew_id.is_a?(Integer) && row["workspace_id"] == workspace_id
      return false unless brew&.values_at("method", "recipient_kind") == %w[espresso guest]
      return false unless unique_value?(seen_ids, id) && unique_value?(seen_brew_ids, brew_id)
      return false unless token.is_a?(String) && token.match?(/\A[A-Za-z0-9_-]+\z/) && token.bytesize <= 255
      return false unless digest == CuppingRequest.token_digest_for(token)
      return false unless unique_value?(seen_tokens, token) && unique_value?(seen_digests, digest)
      return false unless valid_cupping_comment?(row["feedback_comment"])
      return false unless valid_cupping_ip?(row["last_guest_ip"])
      return false unless valid_cupping_timestamps?(row)

      valid_cupping_snapshot?(
        row["snapshot"], identity_attachment_ids: cupping_identity_attachment_ids(workspace_id:, brew:, media_files:)
      )
    end

    def unique_value?(values, value)
      values.add?(value).present?
    end

    def valid_cupping_comment?(value)
      value.nil? || (value.is_a?(String) && value.length <= 2_000)
    end

    def valid_cupping_ip?(value)
      value.nil? || (value.is_a?(String) && IPAddr.new(value).to_s == value)
    rescue IPAddr::InvalidAddressError
      false
    end

    def valid_cupping_timestamps?(row)
      opened_at = archived_time(row["opened_at"])
      expires_at = archived_time(row["feedback_expires_at"])
      closed_at = archived_time(row["closed_at"])
      created_at = archived_time(row["created_at"])
      updated_at = archived_time(row["updated_at"])
      enqueued_at = archived_time(row["expiration_job_enqueued_at"])
      enqueueing_at = archived_time(row["expiration_job_enqueueing_at"])
      return false unless created_at && updated_at && updated_at >= created_at
      return false if row["opened_at"].present? != opened_at.present?
      return false if row["feedback_expires_at"].present? != expires_at.present?
      return false if row["closed_at"].present? != closed_at.present?
      return false if row["expiration_job_enqueued_at"].present? != enqueued_at.present?
      return false if row["expiration_job_enqueueing_at"].present? != enqueueing_at.present?

      if opened_at
        expires_at.present? && expires_at > opened_at && (closed_at.nil? || closed_at >= expires_at)
      else
        expires_at.nil? && closed_at.nil? && enqueued_at.nil? && enqueueing_at.nil?
      end
    end

    def archived_time(value)
      Time.iso8601(value) if value.is_a?(String) && value.present?
    rescue ArgumentError
      nil
    end

    def valid_cupping_snapshot?(snapshot, identity_attachment_ids:)
      return false unless exact_hash?(snapshot, PublicBrewShareSnapshotBuilder::SNAPSHOT_KEYS)
      return false unless identity_attachment_ids.values.all? { |value| value.nil? || value.is_a?(Integer) }

      valid_string?(snapshot["title"], present: true) &&
        valid_cupping_workspace_snapshot?(snapshot["workspace"], identity_attachment_ids[:workspace_logo]) &&
        valid_cupping_user_snapshot?(snapshot["user"], identity_attachment_ids[:user_avatar]) &&
        valid_cupping_brew_snapshot?(snapshot["brew"]) &&
        exact_hash?(snapshot["hero"], []) &&
        valid_cupping_bean_snapshot?(snapshot["bean"]) &&
        valid_cupping_equipment_snapshot?(snapshot["equipment"]) &&
        valid_cupping_tools_snapshot?(snapshot["tools"]) &&
        snapshot["photos"] == [] &&
        valid_archived_time_string?(snapshot["generated_at"]) &&
        valid_cupping_public_media?(snapshot["public_media"], identity_attachment_ids.values.compact)
    end

    def valid_cupping_workspace_snapshot?(value, logo_attachment_id)
      exact_hash?(value, PublicBrewShareSnapshotBuilder::WORKSPACE_KEYS) &&
        valid_string?(value["name"], present: true) &&
        valid_cupping_identity_attachment_id?(value["logo_attachment_id"], logo_attachment_id)
    end

    def valid_cupping_user_snapshot?(value, avatar_attachment_id)
      exact_hash?(value, PublicBrewShareSnapshotBuilder::USER_KEYS) &&
        valid_string?(value["display_label"], present: true) &&
        valid_cupping_identity_attachment_id?(value["avatar_attachment_id"], avatar_attachment_id)
    end

    def valid_cupping_brew_snapshot?(value)
      return false unless exact_hash?(value, PublicBrewShareSnapshotBuilder::BREW_KEYS)

      valid_archived_time_string?(value["occurred_at"]) &&
        value["method"] == "espresso" &&
        valid_nullable_string?(value["public_note"]) &&
        %w[bean_weight_grams ground_weight_grams dose_grams beverage_grams brew_temperature_celsius]
          .all? { |key| valid_decimal_string?(value[key]) } &&
        valid_nullable_string?(value["grind_setting"]) &&
        %w[total_time_seconds preinfusion_seconds first_drip_seconds]
          .all? { |key| valid_nullable_nonnegative_integer?(value[key]) } &&
        [ true, false, nil ].include?(value["channeling"]) &&
        valid_nullable_string?(value["taste_balance"]) &&
        (value["rating"].nil? || value["rating"].is_a?(Integer) && (1..5).cover?(value["rating"])) &&
        valid_nullable_string?(value["retention_marker"]) &&
        valid_public_links?(value["links"]) &&
        exact_hash?(value["recipient"], [ "kind" ]) && value.dig("recipient", "kind") == "guest"
    end

    def valid_cupping_bean_snapshot?(value)
      return false unless exact_hash?(value, PublicBrewShareSnapshotBuilder::BEAN_KEYS)

      %w[name display_name].all? { |key| valid_string?(value[key], present: true) } &&
        %w[roaster_name origin process roast_type roast_level tasting_notes public_note]
          .all? { |key| valid_nullable_string?(value[key]) } &&
        %w[roast_date purchased_on opened_on].all? { |key| valid_date_string?(value[key]) } &&
        valid_decimal_string?(value["roast_degree"]) &&
        value["photo_attachment_id"].nil? && value["photos"] == [] && valid_public_links?(value["links"])
    end

    def valid_cupping_equipment_snapshot?(value)
      return false unless value.is_a?(Array) && value.length <= 2

      roles = value.filter_map { |row| row["role"] if row.is_a?(Hash) }
      return false unless roles.uniq.length == roles.length

      value.all? do |row|
        exact_hash?(row, PublicBrewShareSnapshotBuilder::EQUIPMENT_KEYS) &&
          %w[grinder machine].include?(row["role"]) &&
          %w[name kind].all? { |key| valid_string?(row[key], present: true) } &&
          %w[model public_note].all? { |key| valid_nullable_string?(row[key]) } &&
          row["photo_attachment_id"].nil? && row["photos"] == [] && valid_public_links?(row["links"])
      end
    end

    def valid_cupping_tools_snapshot?(value)
      value.is_a?(Array) && value.all? do |row|
        exact_hash?(row, PublicBrewShareSnapshotBuilder::TOOL_KEYS) &&
          valid_string?(row["name"], present: true) &&
          valid_nullable_string?(row["brew_method"]) &&
          valid_nullable_nonnegative_integer?(row["position"]) &&
          valid_nullable_string?(row["public_note"]) &&
          row["photo_attachment_id"].nil? && row["photos"] == [] && valid_public_links?(row["links"])
      end
    end

    def valid_public_links?(value)
      value.is_a?(Array) && value.all? do |row|
        exact_hash?(row, PublicBrewShareSnapshotBuilder::LINK_KEYS) &&
          valid_character_string?(row["label"], present: true, maximum: 120) &&
          valid_public_url?(row["url"]) &&
          RecordLink::KINDS.include?(row["kind"]) &&
          row["position"].is_a?(Integer) && row["position"] >= 0
      end
    end

    def valid_public_url?(value)
      return false unless valid_string?(value, present: true, maximum: 2_000)

      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def valid_cupping_public_media?(value, expected_attachment_ids)
      return false unless value.is_a?(Array)
      return false unless value.all? do |row|
        exact_hash?(row, PublicBrewShareSnapshotBuilder::PUBLIC_MEDIA_KEYS) && row["attachment_id"].is_a?(Integer)
      end

      attachment_ids = value.pluck("attachment_id")
      attachment_ids.uniq.length == attachment_ids.length && attachment_ids.all? { |id| expected_attachment_ids.include?(id) }
    end

    def valid_string?(value, present: false, maximum: 10_000)
      value.is_a?(String) && value.bytesize <= maximum && (!present || value.present?)
    end

    def valid_nullable_string?(value)
      value.nil? || valid_string?(value)
    end

    def valid_character_string?(value, present: false, maximum: 10_000)
      value.is_a?(String) && value.length <= maximum && (!present || value.present?)
    end

    def valid_decimal_string?(value)
      return true if value.nil?
      return false unless valid_string?(value, present: true, maximum: 100)

      decimal = BigDecimal(value, exception: false)
      decimal.present? && decimal.finite?
    end

    def valid_nullable_nonnegative_integer?(value)
      value.nil? || (value.is_a?(Integer) && value >= 0)
    end

    def valid_archived_time_string?(value)
      archived_time(value).present?
    end

    def valid_date_string?(value)
      value.nil? || (value.is_a?(String) && Date.iso8601(value).iso8601 == value)
    rescue Date::Error
      false
    end

    def exact_hash?(value, keys)
      value.is_a?(Hash) && value.keys.sort == keys.sort
    end

    def valid_cupping_identity_attachment_id?(value, current_attachment_id)
      value.nil? || value.is_a?(Integer) && value == current_attachment_id
    end

    def cupping_identity_attachment_ids(workspace_id:, brew:, media_files:)
      {
        workspace_logo: identity_attachment_id(
          media_files, record_type: "Workspace", record_id: workspace_id, attachment_name: "logo"
        ),
        user_avatar: identity_attachment_id(
          media_files, record_type: "User", record_id: brew["user_id"], attachment_name: "avatar"
        )
      }
    end

    def identity_attachment_id(media_files, record_type:, record_id:, attachment_name:)
      matches = media_files.select do |file|
        file.is_a?(Hash) && file["record_type"] == record_type && file["record_id"] == record_id &&
          file["attachment_name"] == attachment_name
      end
      return if matches.empty?
      return false unless matches.one?

      matches.first["attachment_id"]
    end

    def validate_media_files(zip, media_files, errors)
      media_files.each do |file|
        unless file.is_a?(Hash) && file["path"].is_a?(String)
          errors << "Archive contains an invalid media file."
          next
        end

        path = file["path"]
        entry = zip.find_entry(path)
        unless entry
          errors << "Archive is missing media file #{path}."
          next
        end

        expected_checksum = file["sha256"]
        actual_checksum = Digest::SHA256.hexdigest(entry.get_input_stream.read)
        if expected_checksum.present? && actual_checksum != expected_checksum
          errors << "Media checksum mismatch for #{path}."
        end
      end
    end
end
