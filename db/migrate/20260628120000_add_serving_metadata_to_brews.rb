class AddServingMetadataToBrews < ActiveRecord::Migration[8.1]
  def change
    add_column :brews, :served_for_guest, :boolean, default: false, null: false
    add_column :brews, :guest_name, :string
    add_column :brews, :cup_style, :string
  end
end
