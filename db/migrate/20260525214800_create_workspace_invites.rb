class CreateWorkspaceInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_invites do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :accepted_by, foreign_key: { to_table: :users }
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.string :email_address
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :workspace_invites, :token, unique: true
  end
end

