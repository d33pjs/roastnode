class AddEventTypesToEquipmentEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :equipment_events, :event_types, :string, array: true, default: [], null: false
    execute "UPDATE equipment_events SET event_types = ARRAY[event_type] WHERE event_type IS NOT NULL"
  end

  def down
    remove_column :equipment_events, :event_types
  end
end
