require "ipaddr"
require "set"

class InstanceBackupArchiveValidator
  CUPPING_REQUEST_KEYS = %w[
    id workspace_id brew_id token token_digest snapshot feedback_comment opened_at feedback_expires_at closed_at
    last_guest_ip expiration_job_enqueued_at expiration_job_enqueueing_at created_at updated_at
  ].freeze
  UNSAFE_CUPPING_SNAPSHOT_KEYS = %w[
    token token_digest password password_digest session invite_token signed_id signed_blob_id filename
    recipient_name recipient_user_email_address notes purchase_price purchase_price_cents purchase_source purchase_url
    coffee_origin_url raw_import_data feedback_comment last_guest_ip
  ].freeze

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

      data_path = manifest.dig("data", "path")
      payload = read_json_entry(zip, data_path, errors) if data_path.present?
      validate_payload(payload, errors)

      media_files = Array(manifest["files"])
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

    def validate_payload(payload, errors)
      unless payload["format"] == InstanceReadableExportBuilder::FORMAT
        errors << "Readable export format is not #{InstanceReadableExportBuilder::FORMAT}."
      end
      unless payload["version"] == InstanceReadableExportBuilder::VERSION
        errors << "Readable export version is not #{InstanceReadableExportBuilder::VERSION}."
      end
      errors << "Archive contains an invalid cupping request." unless valid_cupping_requests?(payload)
    end

    def valid_cupping_requests?(payload)
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
            row, workspace_id:, brews:, media_files: Array(payload["media_files"]),
            seen_ids:, seen_brew_ids:, seen_tokens:, seen_digests:
          )
        end
      end
    end

    def valid_cupping_request_row?(row, workspace_id:, brews:, media_files:, seen_ids:, seen_brew_ids:, seen_tokens:, seen_digests:)
      return false unless row.is_a?(Hash) && (CUPPING_REQUEST_KEYS - row.keys).empty?

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
        row["snapshot"], allowed_attachment_ids: cupping_attachment_ids(workspace_id:, brew:, media_files:)
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

    def valid_cupping_snapshot?(value, allowed_attachment_ids:, depth: 0)
      return false if depth > 12

      case value
      when Hash
        value.all? do |key, nested|
          key.is_a?(String) &&
            !UNSAFE_CUPPING_SNAPSHOT_KEYS.include?(key) &&
            (!key.end_with?("attachment_id") || nested.nil? || allowed_attachment_ids.include?(nested)) &&
            valid_cupping_snapshot?(nested, allowed_attachment_ids:, depth: depth + 1)
        end
      when Array
        value.all? { |nested| valid_cupping_snapshot?(nested, allowed_attachment_ids:, depth: depth + 1) }
      when String
        value.bytesize <= 10_000
      when Integer, Float, TrueClass, FalseClass, NilClass
        true
      else
        false
      end
    end

    def cupping_attachment_ids(workspace_id:, brew:, media_files:)
      media_files.filter_map do |file|
        workspace_logo = file["record_type"] == "Workspace" && file["record_id"] == workspace_id && file["attachment_name"] == "logo"
        user_avatar = file["record_type"] == "User" && file["record_id"] == brew["user_id"] && file["attachment_name"] == "avatar"
        file["attachment_id"] if workspace_logo || user_avatar
      end.to_set
    end

    def validate_media_files(zip, media_files, errors)
      media_files.each do |file|
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
