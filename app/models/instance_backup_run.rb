class InstanceBackupRun < ApplicationRecord
  STATUSES = %w[queued running succeeded failed].freeze

  belongs_to :instance_backup_profile

  validates :backup_kind, inclusion: { in: InstanceBackupProfile::BACKUP_KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :succeeded, -> { where(status: "succeeded") }

  def perform!
    now = Time.current
    update!(status: "running", started_at: now, error_message: nil)

    bytes, extension = backup_bytes_and_extension
    FileUtils.mkdir_p(instance_backup_profile.storage_root)
    path = instance_backup_profile.storage_root.join(filename_for(extension, now))
    File.binwrite(path, bytes)

    transaction do
      update!(
        status: "succeeded",
        finished_at: Time.current,
        file_path: path.to_s,
        file_size_bytes: bytes.bytesize,
        checksum_sha256: Digest::SHA256.hexdigest(bytes)
      )
      Activity::Emitter.record!(
        action: "instance_backup_run.succeeded", workspace: nil, subject: self,
        details: { backup_kind:, status: "succeeded", file_size_bytes: bytes.bytesize }
      )
    end

    begin
      instance_backup_profile.enforce_retention!
    rescue StandardError => cleanup_error
      Rails.logger.warn("Backup retention cleanup failed: #{cleanup_error.class}")
    end
  rescue StandardError => error
    if persisted?
      transaction do
        update!(status: "failed", finished_at: Time.current, error_message: "#{error.class}: #{error.message}")
        Activity::Emitter.record!(
          action: "instance_backup_run.failed", workspace: nil, subject: self,
          details: { backup_kind:, status: "failed" }
        )
      end
    end
    raise
  end

  def delete_file!
    FileUtils.rm_f(file_path) if file_path.present? && safe_file_path?
    update!(file_path: nil, file_size_bytes: nil, checksum_sha256: nil)
  end

  private
    def backup_bytes_and_extension
      case backup_kind
      when "full_archive"
        [ InstanceBackupArchiveBuilder.new.call, "zip" ]
      when "readable_json"
        [ JSON.pretty_generate(InstanceReadableExportBuilder.new.call), "json" ]
      end
    end

    def filename_for(extension, timestamp)
      safe_kind = backup_kind.tr("_", "-")
      "roastnode-#{safe_kind}-#{timestamp.utc.strftime('%Y%m%d%H%M%S')}-run-#{id}.#{extension}"
    end

    def safe_file_path?
      return false unless file_path.start_with?(instance_backup_profile.storage_root.to_s)

      File.file?(file_path)
    end
end
