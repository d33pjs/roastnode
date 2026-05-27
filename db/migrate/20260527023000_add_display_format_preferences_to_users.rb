class AddDisplayFormatPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :number_format, :string, null: false, default: "comma_decimal"
    add_column :users, :time_format, :string, null: false, default: "european_24h_seconds"
  end
end
