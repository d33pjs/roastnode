class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "household"
      t.string :default_currency, null: false, default: "EUR"

      t.timestamps
    end
  end
end
