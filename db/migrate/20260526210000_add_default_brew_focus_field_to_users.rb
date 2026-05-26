class AddDefaultBrewFocusFieldToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_brew_focus_field, :string, null: false, default: "bean_weight_grams"
  end
end
