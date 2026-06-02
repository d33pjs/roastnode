class CreateRecipesAndPublicRecipeShares < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :source_brew, foreign_key: { to_table: :brews }
      t.string :title, null: false
      t.string :method, null: false, default: "espresso"
      t.jsonb :profile, null: false, default: {}
      t.jsonb :source_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :recipes, [ :workspace_id, :method, :created_at ]

    add_reference :brews, :recipe, foreign_key: true
    add_column :brews, :recipe_snapshot, :jsonb, null: false, default: {}

    create_table :public_recipe_shares do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.boolean :enabled, null: false, default: false
      t.string :title
      t.string :token, null: false
      t.string :token_digest, null: false
      t.string :password_digest
      t.jsonb :snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :public_recipe_shares, :token, unique: true
    add_index :public_recipe_shares, :token_digest, unique: true
    add_index :public_recipe_shares, [ :workspace_id, :enabled ]
  end
end
