require "test_helper"

class PhotoAttachmentTest < ActiveSupport::TestCase
  test "beans can have photos" do
    attach_photo(beans(:open_household))

    assert beans(:open_household).photos.attached?
  end

  test "brews can have photos" do
    attach_photo(brews(:morning_espresso))

    assert brews(:morning_espresso).photos.attached?
  end

  test "equipment can have photos" do
    attach_photo(equipment(:household_grinder))

    assert equipment(:household_grinder).photos.attached?
  end

  test "equipment events can have photos" do
    attach_photo(equipment_events(:grinder_cleaning))

    assert equipment_events(:grinder_cleaning).photos.attached?
  end

  test "preparation tools can have photos" do
    attach_photo(preparation_tools(:wdt))

    assert preparation_tools(:wdt).photos.attached?
  end

  test "primary photo fallback uses preloaded photo attachments" do
    bean = beans(:open_household)
    attachment = attach_photo(bean)
    preloaded_bean = Bean.includes(:primary_photo_record, photos_attachments: :blob).find(bean.id)
    queries = []

    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries << payload[:sql] if payload[:name] != "SCHEMA"
    end
    primary = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      preloaded_bean.primary_photo_attachment
    end

    assert_equal attachment, primary
    assert_empty queries.grep(/SELECT/i)
  end

  private
    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end
end
