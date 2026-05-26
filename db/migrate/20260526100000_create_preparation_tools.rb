class CreatePreparationTools < ActiveRecord::Migration[8.1]
  def change
    create_table :preparation_tools do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :brew_method, default: "espresso", null: false
      t.boolean :active, default: true, null: false
      t.text :notes

      t.timestamps
    end

    add_index :preparation_tools, [ :workspace_id, :brew_method, :active ]
  end
end
