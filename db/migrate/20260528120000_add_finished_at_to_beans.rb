class AddFinishedAtToBeans < ActiveRecord::Migration[8.1]
  def change
    add_column :beans, :finished_at, :datetime
    add_index :beans, [ :workspace_id, :finished_at ]
  end
end
