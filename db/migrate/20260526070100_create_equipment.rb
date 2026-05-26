class CreateEquipment < ActiveRecord::Migration[8.1]
  def change
    create_table :equipment do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.string :model
      t.text :notes

      t.timestamps
    end

    add_index :equipment, [ :workspace_id, :kind ]
  end
end
