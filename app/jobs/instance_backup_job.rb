class InstanceBackupJob < ApplicationJob
  queue_as :background

  def perform(instance_backup_run)
    instance_backup_run.perform!
  end
end
