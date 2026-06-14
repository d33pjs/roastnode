class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string, null: false, default: "Europe/Berlin"
  end
end
