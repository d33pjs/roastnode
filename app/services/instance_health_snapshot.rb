class InstanceHealthSnapshot
  Check = Data.define(:key, :status, :detail)

  def checks
    [
      database_check,
      storage_check,
      storage_usage_check,
      queue_check,
      rails_check
    ]
  end

  private
    def database_check
      ActiveRecord::Base.connection.active?
      Check.new(key: :database, status: :ok, detail: ActiveRecord::Base.connection_db_config.adapter)
    rescue ActiveRecord::ActiveRecordError => error
      Check.new(key: :database, status: :attention, detail: error.class.name)
    end

    def storage_check
      Check.new(key: :storage, status: :ok, detail: ActiveStorage::Blob.service.name.to_s)
    rescue StandardError => error
      Check.new(key: :storage, status: :attention, detail: error.class.name)
    end

    def storage_usage_check
      Check.new(
        key: :storage_usage,
        status: :ok,
        detail: I18n.t(
          "instance_admin.index.storage_usage_detail",
          blobs: ActiveStorage::Blob.count,
          size: ActiveSupport::NumberHelper.number_to_human_size(ActiveStorage::Blob.sum(:byte_size))
        )
      )
    end

    def queue_check
      Check.new(key: :queue, status: :ok, detail: Rails.application.config.active_job.queue_adapter.to_s)
    end

    def rails_check
      Check.new(key: :rails, status: :ok, detail: I18n.t("instance_admin.index.rails_detail", version: Rails.version, environment: Rails.env))
    end
end
