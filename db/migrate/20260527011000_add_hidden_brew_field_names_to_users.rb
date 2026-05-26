class AddHiddenBrewFieldNamesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hidden_brew_field_names, :jsonb, default: [], null: false
  end
end
