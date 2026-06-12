class CreatePublicBeanShares < ActiveRecord::Migration[8.1]
  def change
    create_table :public_bean_shares do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :bean, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.string :token_digest, null: false
      t.boolean :enabled, null: false, default: false
      t.string :title
      t.string :password_digest
      t.integer :selected_photo_attachment_ids, array: true, null: false, default: []
      t.jsonb :snapshot, null: false, default: {}
      t.integer :views_count, null: false, default: 0

      t.timestamps
    end

    add_index :public_bean_shares, :token, unique: true
    add_index :public_bean_shares, :token_digest, unique: true
    add_index :public_bean_shares, [ :workspace_id, :enabled ]
  end
end
