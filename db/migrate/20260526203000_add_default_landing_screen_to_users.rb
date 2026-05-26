class AddDefaultLandingScreenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_landing_screen, :string, null: false, default: "dashboard"
  end
end
