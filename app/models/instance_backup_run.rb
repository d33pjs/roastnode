class InstanceBackupRun < ApplicationRecord
  STATUSES = %w[queued running succeeded failed].freeze

  belongs_to :instance_backup_profile

  validates :backup_kind, inclusion: { in: InstanceBackupProfile::BACKUP_KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :succeeded, -> { where(status: "succeeded") }

  def perform!
    now = Time.current
    path = nil
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
    remove_failed_backup_file(path)
    persist_failed_state(error) if persisted?
    raise error
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

    def remove_failed_backup_file(path)
      return if path.blank?

      candidate = Pathname(path).expand_path
      storage_root = instance_backup_profile.storage_root.expand_path
      return unless candidate.dirname == storage_root

      FileUtils.rm_f(candidate)
    rescue StandardError => cleanup_error
      Rails.logger.warn("Failed backup file cleanup failed: #{cleanup_error.class}")
    end

    def persist_failed_state(error)
      attributes = {
        status: "failed",
        finished_at: Time.current,
        error_message: "#{error.class}: #{error.message}",
        file_path: nil,
        file_size_bytes: nil,
        checksum_sha256: nil
      }
      transaction do
        update!(attributes)
        Activity::Emitter.record!(
          action: "instance_backup_run.failed", workspace: nil, subject: self,
          details: { backup_kind:, status: "failed" }
        )
      end
    rescue StandardError => audit_error
      Rails.logger.error("Backup failure audit transaction failed: #{audit_error.class}")
      persist_failed_state_without_activity(attributes)
    end

    def persist_failed_state_without_activity(attributes)
      reload
      update!(attributes)
    rescue StandardError => state_error
      Rails.logger.error("Backup failure state persistence failed: #{state_error.class}")
    end
end
