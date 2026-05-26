class CreateDataImports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_imports do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :summary, null: false, default: {}
      t.jsonb :warnings, null: false, default: []
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :data_imports, [ :workspace_id, :source, :created_at ]
  end
end
