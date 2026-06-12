require "test_helper"

class PublicBeanShareRefresherTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "refreshes shares for bean changes" do
    bean = beans(:open_household)
    share = create_share(bean)

    bean.update!(public_note: "Updated public note")
    PublicBeanShareRefresher.refresh_for(bean)

    assert_equal "Updated public note", share.reload.snapshot.dig("bean", "public_note")
  end

  test "refreshes shares for brew changes" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, public_note: "Old note")
    share = create_share(bean)

    brew.update!(public_note: "New brew note")
    PublicBeanShareRefresher.refresh_for(brew)

    assert_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "New brew note"
  end

  test "refresh removes selected photos that no longer belong to bean" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean, selected_photo_attachment_ids: [ photo.id ])

    photo.destroy
    PublicBeanShareRefresher.refresh(share)

    assert_equal [], share.reload.selected_photo_attachment_ids
    assert_equal [], share.snapshot.fetch("photos")
  end

  private
    def create_share(bean, selected_photo_attachment_ids: [])
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
