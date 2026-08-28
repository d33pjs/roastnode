class AddCuppingRequestExpirationDispatch < ActiveRecord::Migration[8.1]
  def change
    add_column :cupping_requests, :expiration_job_enqueued_at, :datetime
    add_index :cupping_requests, :feedback_expires_at,
      name: "index_cupping_requests_on_open_expiration",
      where: "opened_at IS NOT NULL AND closed_at IS NULL"
  end
end
