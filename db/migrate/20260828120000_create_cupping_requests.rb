require "digest"
require "securerandom"

class CreateCuppingRequests < ActiveRecord::Migration[8.1]
  CuppingRequestRow = Class.new(ActiveRecord::Base) do
    self.table_name = "cupping_requests"
  end

  def up
    create_table :cupping_requests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :brew, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.string :token_digest, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.text :feedback_comment
      t.datetime :opened_at
      t.datetime :feedback_expires_at
      t.datetime :closed_at
      t.string :last_guest_ip
      t.timestamps
    end
    add_index :cupping_requests, :token, unique: true
    add_index :cupping_requests, :token_digest, unique: true
    add_check_constraint :cupping_requests,
      "char_length(feedback_comment) <= 2000", name: "cupping_requests_comment_length"
    backfill_guest_espressos
  end

  def down
    drop_table :cupping_requests
  end

  private
    def backfill_guest_espressos
      now = Time.current
      rows = select_all(<<~SQL).map do |row|
        SELECT id FROM brews
        WHERE method = 'espresso' AND recipient_kind = 'guest'
      SQL
        brew = Brew.find(row.fetch("id"))
        token = SecureRandom.urlsafe_base64(24)
        {
          brew_id: brew.id,
          workspace_id: brew.workspace_id,
          token:,
          token_digest: Digest::SHA256.hexdigest(token),
          snapshot: PublicBrewShareSnapshotBuilder.new(
            brew:, title: PublicBrewShare.default_title_for(brew), selected_photo_attachment_ids: []
          ).call,
          created_at: now,
          updated_at: now
        }
      end
      CuppingRequestRow.insert_all!(rows) if rows.any?
    end
end
