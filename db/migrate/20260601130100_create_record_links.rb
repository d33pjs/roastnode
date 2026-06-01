class CreateRecordLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :record_links do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :linkable, null: false, polymorphic: true
      t.string :label, null: false
      t.string :url, null: false
      t.string :kind, null: false, default: "info"
      t.string :visibility, null: false, default: "private"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :record_links, [ :workspace_id, :linkable_type, :linkable_id, :position ], name: "idx_record_links_workspace_linkable_position"
  end
end
