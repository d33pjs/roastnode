require "roastnode/runtime_settings"

class InstanceOperationsSnapshot
  Summary = Data.define(:key, :status, :value, :detail)
  FailedJobRow = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message)
  MailFailureRow = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message)
  BackupProfileRow = Data.define(:id, :name, :backup_kind, :enabled, :schedule, :latest_status, :latest_at, :last_success_at)
  BackupFailureRow = Data.define(:id, :profile_name, :backup_kind, :failed_at, :error_message)

  def initialize(queue_reader: SolidQueueReader.new, runtime_settings: Roastnode::RuntimeSettings.new)
    @queue_reader = queue_reader
    @runtime_settings = runtime_settings
  end

  def queue_status
    return unavailable_queue_status unless queue_reader.available?

    counts = queue_counts_by_key
    return unavailable_queue_status unless queue_reader.available?

    failed = counts.fetch(:failed_jobs, 0)
    blocked = counts.fetch(:blocked_jobs, 0)
    pending = counts.values_at(:ready_jobs, :scheduled_jobs, :claimed_jobs, :blocked_jobs).compact.sum
    status = failed.positive? || blocked.positive? ? :attention : :ok

    Summary.new(
      key: :background_jobs,
      status:,
      value: I18n.t("instance_admin.index.operation_pending_jobs", count: pending),
      detail: I18n.t("instance_admin.index.operation_queue_detail", failed:, blocked:)
    )
  end

  def queue_counts
    return [] unless queue_reader.available?

    counts = queue_counts_by_key
    return [] unless queue_reader.available?

    @queue_counts ||= counts.map do |key, value|
      Summary.new(
        key:,
        status: key == :failed_jobs && value.positive? ? :attention : :ok,
        value:,
        detail: nil
      )
    end
  end

  def failed_jobs(limit: 5)
    return [] unless queue_reader.available?

    @failed_jobs_by_limit ||= {}
    @failed_jobs_by_limit[limit] ||= queue_reader.recent_failures(limit:).map do |failure|
      FailedJobRow.new(
        id: failure.id,
        class_name: failure.class_name,
        queue_name: failure.queue_name,
        failed_at: failure.failed_at,
        error_message: safe_error_message(failure.error_message)
      )
    end
  end

  def mail_status
    smtp_settings = runtime_settings.smtp_settings
    status = smtp_settings ? :ok : :attention

    Summary.new(
      key: :mail_delivery,
      status:,
      value: smtp_settings ? I18n.t("instance_admin.index.operation_mail_enabled") : I18n.t("instance_admin.index.operation_mail_disabled"),
      detail: smtp_settings ? I18n.t("instance_admin.index.operation_mail_enabled_detail", address: smtp_settings.fetch(:address)) : I18n.t("instance_admin.index.operation_mail_disabled_detail")
    )
  end

  def mail_failures(limit: 5)
    return [] unless queue_reader.available?

    @mail_failures_by_limit ||= {}
    @mail_failures_by_limit[limit] ||= queue_reader.recent_failures(limit: limit * 5)
      .select { |failure| mail_failure?(failure) }
      .first(limit)
      .map do |failure|
        MailFailureRow.new(
          id: failure.id,
          class_name: failure.class_name,
          queue_name: failure.queue_name,
          failed_at: failure.failed_at,
          error_message: safe_error_message(failure.error_message)
        )
      end
  end

  def backup_status
    failed = InstanceBackupRun.where(status: "failed").count
    missing = missing_backup_kinds
    enabled = backup_profiles.count(&:enabled?)
    status = failed.positive? || missing.any? ? :attention : :ok

    Summary.new(
      key: :backups,
      status:,
      value: I18n.t("instance_admin.index.operation_enabled_profiles", count: enabled, total: InstanceBackupProfile::BACKUP_KINDS.size),
      detail: backup_status_detail(failed:, missing:)
    )
  end

  def backup_profile_rows
    @backup_profile_rows ||= backup_profiles.map do |profile|
      latest_run = profile.instance_backup_runs.max_by(&:created_at)
      last_success = profile.instance_backup_runs.select { |run| run.status == "succeeded" }.max_by(&:finished_at)

      BackupProfileRow.new(
        id: profile.id,
        name: profile.name,
        backup_kind: profile.backup_kind,
        enabled: profile.enabled?,
        schedule: profile.schedule,
        latest_status: latest_run&.status,
        latest_at: latest_run&.created_at,
        last_success_at: last_success&.finished_at
      )
    end
  end

  def backup_failures(limit: 5)
    @backup_failures_by_limit ||= {}
    @backup_failures_by_limit[limit] ||= InstanceBackupRun
      .where(status: "failed")
      .includes(:instance_backup_profile)
      .order(created_at: :desc)
      .limit(limit)
      .map do |run|
        BackupFailureRow.new(
          id: run.id,
          profile_name: run.instance_backup_profile.name,
          backup_kind: run.backup_kind,
          failed_at: run.finished_at || run.created_at,
          error_message: safe_error_message(run.error_message)
        )
      end
  end

  def export_status
    Summary.new(
      key: :workspace_exports,
      status: :ok,
      value: I18n.t("instance_admin.index.operation_workspace_exports_value"),
      detail: I18n.t("instance_admin.index.operation_workspace_exports_detail")
    )
  end

  private
    attr_reader :queue_reader, :runtime_settings

    def unavailable_queue_status
      Summary.new(
        key: :background_jobs,
        status: :attention,
        value: I18n.t("instance_admin.index.operation_unavailable"),
        detail: queue_reader.unavailable_detail.presence || I18n.t("instance_admin.index.operation_queue_unavailable")
      )
    end

    def queue_counts_by_key
      @queue_counts_by_key ||= queue_reader.counts
    end

    def backup_profiles
      @backup_profiles ||= InstanceBackupProfile.includes(:instance_backup_runs).order(:backup_kind, :id).to_a
    end

    def missing_backup_kinds
      InstanceBackupProfile::BACKUP_KINDS - backup_profiles.map(&:backup_kind)
    end

    def backup_status_detail(failed:, missing:)
      if failed.positive? && missing.any?
        I18n.t(
          "instance_admin.index.operation_backups_failed_and_missing",
          count: failed,
          missing: missing.map { |kind| I18n.t("instance_admin.index.backup_kind_labels.#{kind}") }.to_sentence
        )
      elsif failed.positive?
        I18n.t("instance_admin.index.operation_backups_failed", count: failed)
      elsif missing.any?
        I18n.t(
          "instance_admin.index.operation_backups_missing",
          missing: missing.map { |kind| I18n.t("instance_admin.index.backup_kind_labels.#{kind}") }.to_sentence
        )
      else
        I18n.t("instance_admin.index.operation_backups_ok")
      end
    end

    def safe_error_message(message)
      message.to_s
        .gsub(/((?:access_)?token|password|secret|session)([\w-]*)?(\s*[:=]\s*)[^\s&]+/i, "\\1\\2\\3[REDACTED]")
        .truncate(220)
    end

    def mail_failure?(failure)
      class_name = failure.class_name.to_s
      error_message = failure.error_message.to_s

      class_name.match?(/Mailer|MailDeliveryJob/) ||
        error_message.match?(/ActionMailer|Mail::|Net::SMTP|SMTP/i)
    end

    class SolidQueueReader
      QueueFailure = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message)

      COUNT_MODELS = {
        ready_jobs: "SolidQueue::ReadyExecution",
        scheduled_jobs: "SolidQueue::ScheduledExecution",
        claimed_jobs: "SolidQueue::ClaimedExecution",
        blocked_jobs: "SolidQueue::BlockedExecution",
        failed_jobs: "SolidQueue::FailedExecution",
        worker_processes: "SolidQueue::Process"
      }.freeze

      attr_reader :unavailable_detail

      def available?
        return @available unless @available.nil?

        @available = COUNT_MODELS.values.all? do |model_name|
          model = model_name.constantize
          model.connection_pool.with_connection do |connection|
            connection.data_source_exists?(model.table_name)
          end
        end
        @unavailable_detail = I18n.t("instance_admin.index.operation_queue_tables_missing") unless @available
        @available
      rescue NameError, ActiveRecord::ActiveRecordError => error
        @available = false
        @unavailable_detail = I18n.t("instance_admin.index.operation_queue_error", error: error.class.name)
      end

      def counts
        COUNT_MODELS.transform_values { |model_name| model_name.constantize.count }
      rescue ActiveRecord::ActiveRecordError => error
        @available = false
        @unavailable_detail = I18n.t("instance_admin.index.operation_queue_error", error: error.class.name)
        {}
      end

      def recent_failures(limit:)
        SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(limit).map do |failure|
          QueueFailure.new(
            id: failure.id,
            class_name: failure.job.class_name,
            queue_name: failure.job.queue_name,
            failed_at: failure.created_at,
            error_message: failure_message(failure)
          )
        end
      rescue ActiveRecord::ActiveRecordError => error
        @available = false
        @unavailable_detail = I18n.t("instance_admin.index.operation_queue_error", error: error.class.name)
        []
      end

      private
        def failure_message(failure)
          if failure.respond_to?(:exception_class) && failure.exception_class.present?
            "#{failure.exception_class}: #{failure.message}"
          else
            failure.error.to_s
          end
        end
    end
end
