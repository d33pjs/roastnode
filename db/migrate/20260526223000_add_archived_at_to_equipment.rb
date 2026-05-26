class AddArchivedAtToEquipment < ActiveRecord::Migration[8.1]
  def change
    add_column :equipment, :archived_at, :datetime
    add_index :equipment, [ :workspace_id, :archived_at ]
  end
end
