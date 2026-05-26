module HasPrimaryPhoto
  extend ActiveSupport::Concern

  included do
    belongs_to :primary_photo_record, class_name: "ActiveStorage::Attachment", optional: true,
      foreign_key: :primary_photo_attachment_id
  end

  def primary_photo_attachment
    stored_primary = primary_photo_record
    return stored_primary if stored_primary&.record == self && stored_primary.name == "photos"

    photos.attachments.order(:id).first
  end

  def set_primary_photo!(attachment)
    raise ActiveRecord::RecordNotFound unless attachment.record == self && attachment.name == "photos"

    update!(primary_photo_attachment_id: attachment.id)
  end
end
