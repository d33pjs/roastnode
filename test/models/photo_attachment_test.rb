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

  test "bean stored primary photo uses its controller preload without a select" do
    bean = beans(:open_household)
    attachment = attach_photo(bean)
    bean.set_primary_photo!(attachment)
    preloaded_bean = Bean.includes(primary_photo_record: :blob, photos_attachments: :blob).find(bean.id)

    assert_primary_photo_without_select(preloaded_bean, attachment)
  end

  test "brew stored primary photo uses its controller preload without a select" do
    brew = brews(:morning_espresso)
    attachment = attach_photo(brew)
    brew.set_primary_photo!(attachment)
    preloaded_brew = Brew.includes(primary_photo_record: :blob, photos_attachments: :blob).find(brew.id)

    assert_primary_photo_without_select(preloaded_brew, attachment)
  end

  test "stored primary photo falls back when it belongs to another record" do
    bean = beans(:open_household)
    fallback = attach_photo(bean)
    mismatched = attach_photo(brews(:morning_espresso))
    bean.update_column(:primary_photo_attachment_id, mismatched.id)
    preloaded_bean = Bean.includes(primary_photo_record: :blob, photos_attachments: :blob).find(bean.id)

    assert_equal fallback, preloaded_bean.primary_photo_attachment
  end

  private
    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end

    def assert_primary_photo_without_select(record, expected_attachment)
      queries = []
      callback = lambda do |_name, _started, _finished, _unique_id, payload|
        queries << payload[:sql] if payload[:name] != "SCHEMA"
      end
      primary = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        record.primary_photo_attachment
      end

      assert_equal expected_attachment, primary
      assert_empty queries.grep(/SELECT/i)
    end
end
