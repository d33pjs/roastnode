require "zip"

class InstanceBackupArchiveBuilder
  FORMAT = "roastnode.instance_backup_archive"
  VERSION = 1

  def initialize(generated_at: Time.current)
    @generated_at = generated_at
    @readable_export_builder = InstanceReadableExportBuilder.new(generated_at:)
  end

  def call
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("manifest.json")
      zip.write(JSON.pretty_generate(manifest))

      zip.put_next_entry("data/instance-readable-export.json")
      zip.write(JSON.pretty_generate(readable_export_payload))

      media_file_entries.each do |entry|
        zip.put_next_entry(entry.fetch(:path))
        zip.write(entry.fetch(:attachment).blob.download)
      end
    end

    buffer.string
  end

  private
    attr_reader :generated_at, :readable_export_builder

    def manifest
      {
        format: FORMAT,
        version: VERSION,
        generated_at: generated_at.iso8601,
        data: {
          path: "data/instance-readable-export.json",
          format: InstanceReadableExportBuilder::FORMAT,
          version: InstanceReadableExportBuilder::VERSION
        },
        files: media_file_entries.map { |entry| manifest_file_payload(entry) }
      }
    end

    def readable_export_payload
      @readable_export_payload ||= readable_export_builder.call
    end

    def media_file_entries
      @media_file_entries ||= readable_export_builder.media_file_entries
    end

    def manifest_file_payload(entry)
      bytes = entry.fetch(:attachment).blob.download
      entry.except(:attachment).merge(sha256: Digest::SHA256.hexdigest(bytes))
    end
end
