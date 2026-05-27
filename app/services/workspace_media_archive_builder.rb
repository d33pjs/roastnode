require "zip"

class WorkspaceMediaArchiveBuilder
  FORMAT = "roastnode.workspace_media_archive"
  VERSION = 1

  def initialize(workspace, generated_at: Time.current)
    @workspace = workspace
    @generated_at = generated_at
  end

  def call
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("manifest.json")
      zip.write(JSON.pretty_generate(manifest))

      zip.put_next_entry("data/workspace-export.json")
      zip.write(JSON.pretty_generate(workspace_export_payload))

      files.each do |file|
        zip.put_next_entry(file.fetch(:path))
        zip.write(file.fetch(:attachment).blob.download)
      end
    end

    buffer.string
  end

  private
    attr_reader :workspace, :generated_at

    def manifest
      {
        format: FORMAT,
        version: VERSION,
        generated_at: generated_at.iso8601,
        workspace: {
          id: workspace.id,
          name: workspace.name
        },
        files: files.map { |file| file.except(:attachment) }
      }
    end

    def workspace_export_payload
      @workspace_export_payload ||= WorkspaceExportBuilder.new(workspace, generated_at:).call
    end

    def files
      @files ||= media_attachments.map { |attachment| file_payload(attachment) }
    end

    def media_attachments
      [
        workspace_identity_attachments,
        photo_attachments(workspace.beans.order(:id)),
        photo_attachments(workspace.equipment.order(:id)),
        photo_attachments(workspace.preparation_tools.order(:id)),
        photo_attachments(workspace.brews.order(:id)),
        photo_attachments(workspace.equipment_events.order(:id))
      ].flatten
    end

    def workspace_identity_attachments
      [ workspace.logo.attachment, workspace.banner.attachment ].compact
    end

    def photo_attachments(records)
      records.flat_map do |record|
        record.photos.attachments.includes(:blob).order(:id).to_a
      end
    end

    def file_payload(attachment)
      {
        path: archive_path(attachment),
        record_type: attachment.record_type,
        record_id: attachment.record_id,
        attachment_id: attachment.id,
        attachment_name: attachment.name,
        filename: attachment.blob.filename.to_s,
        content_type: attachment.blob.content_type,
        byte_size: attachment.blob.byte_size,
        checksum: attachment.blob.checksum,
        created_at: attachment.created_at.iso8601,
        attachment:
      }
    end

    def archive_path(attachment)
      record = attachment.record
      [
        "media",
        record.model_name.collection,
        record.id,
        attachment.name,
        "#{attachment.id}-#{safe_filename(attachment.blob.filename.to_s)}"
      ].join("/")
    end

    def safe_filename(filename)
      sanitized = File.basename(filename).gsub(/[^A-Za-z0-9._-]+/, "_").sub(/\A[.]+/, "")
      sanitized.presence || "attachment"
    end
end
