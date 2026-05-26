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

  private
    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
    end
end
