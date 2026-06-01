class CreateHouseholdInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :household_invites do |t|
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :accepted_by, foreign_key: { to_table: :users }
      t.references :workspace, foreign_key: true
      t.string :token, null: false
      t.string :email_address, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :household_invites, :token, unique: true
    add_index :household_invites, :email_address
  end
end
