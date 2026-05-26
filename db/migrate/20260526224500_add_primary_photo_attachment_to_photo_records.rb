class AddPrimaryPhotoAttachmentToPhotoRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :beans, :primary_photo_attachment_id, :bigint
    add_column :brews, :primary_photo_attachment_id, :bigint
    add_column :equipment, :primary_photo_attachment_id, :bigint
    add_column :equipment_events, :primary_photo_attachment_id, :bigint

    add_index :beans, :primary_photo_attachment_id
    add_index :brews, :primary_photo_attachment_id
    add_index :equipment, :primary_photo_attachment_id
    add_index :equipment_events, :primary_photo_attachment_id
  end
end
