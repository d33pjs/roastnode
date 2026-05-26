class AddLifecycleFieldsToPreparationTools < ActiveRecord::Migration[8.1]
  def change
    add_column :preparation_tools, :position, :integer, default: 0, null: false
    add_column :preparation_tools, :primary_photo_attachment_id, :bigint

    add_index :preparation_tools, [ :workspace_id, :active, :position ], name: "idx_preparation_tools_workspace_active_position"
    add_index :preparation_tools, :primary_photo_attachment_id
  end
end
