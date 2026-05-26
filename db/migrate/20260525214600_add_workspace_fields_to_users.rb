class AddWorkspaceFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :display_name, :string
    add_column :users, :instance_admin, :boolean, null: false, default: false
    add_reference :users, :active_workspace, foreign_key: { to_table: :workspaces }
  end
end
