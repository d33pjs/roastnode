class CreateEquipmentEventItems < ActiveRecord::Migration[8.1]
  def change
    create_table :equipment_event_items do |t|
      t.references :equipment_event, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true

      t.timestamps
    end

    add_index :equipment_event_items, [ :equipment_event_id, :equipment_id ], unique: true
  end
end
