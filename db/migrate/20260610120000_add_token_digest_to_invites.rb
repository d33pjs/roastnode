require "digest"

class AddTokenDigestToInvites < ActiveRecord::Migration[8.1]
  WorkspaceInviteRecord = Class.new(ActiveRecord::Base) do
    self.table_name = "workspace_invites"
  end

  HouseholdInviteRecord = Class.new(ActiveRecord::Base) do
    self.table_name = "household_invites"
  end

  def up
    add_column :workspace_invites, :token_digest, :string
    add_column :household_invites, :token_digest, :string

    backfill_token_digest(WorkspaceInviteRecord)
    backfill_token_digest(HouseholdInviteRecord)

    change_column_null :workspace_invites, :token_digest, false
    change_column_null :household_invites, :token_digest, false
    add_index :workspace_invites, :token_digest, unique: true
    add_index :household_invites, :token_digest, unique: true
  end

  def down
    remove_index :household_invites, :token_digest
    remove_index :workspace_invites, :token_digest
    remove_column :household_invites, :token_digest
    remove_column :workspace_invites, :token_digest
  end

  private
    def backfill_token_digest(record_class)
      record_class.reset_column_information
      record_class.find_each do |record|
        next if record.token.blank?

        record.update_columns(token_digest: Digest::SHA256.hexdigest(record.token))
      end
    end
end
