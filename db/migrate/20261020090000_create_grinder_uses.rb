class CreateGrinderUses < ActiveRecord::Migration[8.1]
  def change
    create_table :grinder_uses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :bean, null: false, foreign_key: true
      t.references :grinder, foreign_key: { to_table: :equipment }
      t.string :method, null: false
      t.string :grind_setting
      t.uuid :confirmation_key, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :grinder_uses, %i[workspace_id user_id confirmation_key], unique: true, name: "index_grinder_uses_on_confirmation"
    add_index :grinder_uses, %i[workspace_id grinder_id occurred_at]
    add_column :brews, :ground_at, :datetime
    add_column :brews, :client_draft_key, :uuid
    add_index :brews, %i[workspace_id user_id client_draft_key], unique: true, name: "index_brews_on_client_draft_key"
  end
end
