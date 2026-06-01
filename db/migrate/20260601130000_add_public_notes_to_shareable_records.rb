class AddPublicNotesToShareableRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :brews, :public_note, :text
    add_column :beans, :public_note, :text
    add_column :equipment, :public_note, :text
    add_column :preparation_tools, :public_note, :text
  end
end
