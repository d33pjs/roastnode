class InstanceBackupSchedulerJob < ApplicationJob
  queue_as :background

  def perform(now: Time.current)
    InstanceBackupProfile.find_each do |profile|
      profile.enqueue_run!(now:) if profile.due_for_enqueue?(now)
    end
  end
end
