class AddLifecyclePolishFieldsToBeans < ActiveRecord::Migration[8.1]
  def change
    add_column :beans, :continent, :string
    add_column :beans, :country_of_manufacturer, :string
    add_column :beans, :manufacturer, :string
  end
end
