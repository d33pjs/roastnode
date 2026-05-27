class InstanceBackupProfile < ApplicationRecord
  BACKUP_KINDS = %w[full_archive readable_json].freeze
  SCHEDULES = %w[manual daily weekly].freeze
  DEFAULT_STORAGE_PATH = "storage/instance_backups"
  DEFAULT_NAMES = {
    "full_archive" => "Full instance archive",
    "readable_json" => "Readable all-households JSON"
  }.freeze

  has_many :instance_backup_runs, dependent: :destroy

  validates :name, presence: true
  validates :backup_kind, inclusion: { in: BACKUP_KINDS }
  validates :schedule, inclusion: { in: SCHEDULES }
  validates :storage_path, presence: true
  validates :retention_count, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :storage_path_stays_inside_application

  def self.default_name_for(backup_kind)
    DEFAULT_NAMES.fetch(backup_kind, "Instance backup")
  end

  def due_for_enqueue?(now = Time.current)
    return false unless enabled?
    return false if schedule == "manual"

    last_enqueued_at.blank? || now >= last_enqueued_at + schedule_interval
  end

  def enqueue_run!(now: Time.current, track_schedule: true)
    transaction do
      run = instance_backup_runs.create!(backup_kind:)
      update!(last_enqueued_at: now) if track_schedule
      InstanceBackupJob.perform_later(run)
      run
    end
  end

  def storage_root
    Rails.root.join(storage_path).cleanpath
  end

  def enforce_retention!
    stale_runs = instance_backup_runs.succeeded.where.not(file_path: nil).order(finished_at: :desc, id: :desc).to_a.drop(retention_count)
    stale_runs.each(&:delete_file!)
  end

  private
    def schedule_interval
      case schedule
      when "daily" then 1.day
      when "weekly" then 1.week
      else 0.seconds
      end
    end

    def storage_path_stays_inside_application
      path = Pathname.new(storage_path.to_s)

      if path.absolute? || path.each_filename.any? { |part| part == ".." }
        errors.add(:storage_path, "must be relative to the application root")
      end
    end
end
