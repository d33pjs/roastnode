class CreateInventoryAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_adjustments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :bean, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :brew, foreign_key: true
      t.decimal :delta_grams, precision: 10, scale: 2, null: false
      t.string :reason, null: false
      t.text :note
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :inventory_adjustments, [ :workspace_id, :occurred_at ]
  end
end
