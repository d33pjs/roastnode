require "test_helper"

class PublicBeanMediaControllerTest < ActionDispatch::IntegrationTest
  include PhotoTestHelper

  test "streams selected public bean media through opaque handle" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ])
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "rejects unselected and private media" do
    bean = beans(:open_household)
    selected = attach_photo(bean)
    unselected = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ selected.id ])

    assert_nil share.public_media_handle_for(unselected.id)
    get public_bean_media_path(share.token, unselected.id)

    assert_response :not_found
  end

  test "password protected media returns not found until unlocked" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ], password: "coffee")
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle)
    assert_response :not_found

    post unlock_public_bean_page_path(share.token), params: { password: "coffee" }
    get public_bean_media_path(share.token, handle)
    assert_response :success
  end

  private
    def create_share(bean:, selected_photo_attachment_ids:, password: nil)
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        password:,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
