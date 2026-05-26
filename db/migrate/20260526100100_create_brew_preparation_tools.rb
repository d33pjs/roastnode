class CreateBrewPreparationTools < ActiveRecord::Migration[8.1]
  def change
    create_table :brew_preparation_tools do |t|
      t.references :brew, null: false, foreign_key: true
      t.references :preparation_tool, foreign_key: true
      t.string :tool_name, null: false
      t.string :brew_method, default: "espresso", null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :brew_preparation_tools, [ :brew_id, :position ]
  end
end
