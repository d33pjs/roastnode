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

    update!(
      status: "succeeded",
      finished_at: Time.current,
      file_path: path.to_s,
      file_size_bytes: bytes.bytesize,
      checksum_sha256: Digest::SHA256.hexdigest(bytes)
    )
    instance_backup_profile.enforce_retention!
  rescue StandardError => error
    update!(status: "failed", finished_at: Time.current, error_message: "#{error.class}: #{error.message}") if persisted?
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
