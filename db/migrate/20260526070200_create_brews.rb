class CreateBrews < ActiveRecord::Migration[8.1]
  def change
    create_table :brews do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :bean, null: false, foreign_key: true
      t.references :grinder, foreign_key: { to_table: :equipment }
      t.references :machine, foreign_key: { to_table: :equipment }
      t.string :method, default: "espresso", null: false
      t.datetime :occurred_at, null: false
      t.decimal :bean_weight_grams, precision: 8, scale: 2, null: false
      t.decimal :ground_weight_grams, precision: 8, scale: 2
      t.decimal :dose_grams, precision: 8, scale: 2
      t.decimal :beverage_grams, precision: 8, scale: 2
      t.string :grind_setting
      t.decimal :brew_temperature_celsius, precision: 5, scale: 2
      t.integer :total_time_seconds
      t.integer :preinfusion_seconds
      t.integer :first_drip_seconds
      t.boolean :channeling
      t.string :taste_balance, default: "unknown", null: false
      t.integer :rating
      t.text :notes
      t.string :retention_marker, default: "unknown", null: false

      t.timestamps
    end

    add_index :brews, [ :workspace_id, :occurred_at ]
  end
end
