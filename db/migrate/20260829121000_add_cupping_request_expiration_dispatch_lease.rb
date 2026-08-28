class AddCuppingRequestExpirationDispatchLease < ActiveRecord::Migration[8.1]
  def change
    add_column :cupping_requests, :expiration_job_enqueueing_at, :datetime
  end
end
