class CreatePublicBeanCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :public_bean_collections do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.string :token_digest, null: false
      t.string :title, null: false
      t.text :description
      t.boolean :enabled, null: false, default: false
      t.string :mode, null: false, default: "selected"
      t.jsonb :selected_share_ids, null: false, default: []
      t.jsonb :excluded_share_ids, null: false, default: []
      t.jsonb :representative_share_ids, null: false, default: []
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end
    add_index :public_bean_collections, :token, unique: true
    add_index :public_bean_collections, :token_digest, unique: true
    add_check_constraint :public_bean_collections, "mode IN ('selected', 'automatic')", name: "public_bean_collection_mode"

    add_column :public_bean_shares, :public_price_cents, :integer
    add_column :public_bean_shares, :public_price_currency, :string
    add_column :public_bean_shares, :public_price_recorded_on, :date
    add_check_constraint :public_bean_shares, "public_price_cents IS NULL OR public_price_cents >= 0", name: "public_bean_share_price_nonnegative"
  end
end
