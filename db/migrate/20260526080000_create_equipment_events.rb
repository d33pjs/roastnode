class CreateEquipmentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :equipment_events do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :equipment_events, [ :workspace_id, :occurred_at ]
    add_index :equipment_events, [ :workspace_id, :event_type ]
  end
end
