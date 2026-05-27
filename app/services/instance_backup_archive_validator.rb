class InstanceBackupArchiveValidator
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
