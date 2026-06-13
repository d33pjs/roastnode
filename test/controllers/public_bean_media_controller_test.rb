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

  test "rejects rogue manifest media from another workspace" do
    bean = beans(:open_household)
    selected = attach_photo(bean)
    rogue = attach_photo(beans(:other_workspace_open))
    share = create_share(bean:, selected_photo_attachment_ids: [ selected.id ])
    snapshot = share.snapshot.deep_dup
    snapshot["public_media"] << { "attachment_id" => rogue.id }
    share.update!(snapshot:)
    forged_handle = public_bean_media_handle_for(share, rogue.id)

    assert_nil share.public_media_handle_for(rogue.id)

    get public_bean_media_path(share.token, forged_handle)

    assert_response :not_found
  end

  test "rejects handle minted for another public bean share" do
    first_photo = attach_photo(beans(:open_household))
    first_share = create_share(bean: beans(:open_household), selected_photo_attachment_ids: [ first_photo.id ])
    second_photo = attach_photo(beans(:second_open_household))
    second_share = create_share(bean: beans(:second_open_household), selected_photo_attachment_ids: [ second_photo.id ])
    second_handle = second_share.public_media_handle_for(second_photo.id)

    get public_bean_media_path(first_share.token, second_handle)

    assert_response :not_found
  end

  test "rejects media for disabled share" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ], enabled: false)
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle)

    assert_response :not_found
  end

  test "rejects unknown public bean media variant" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ])
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle, variant: "large")

    assert_response :not_found
  end

  private
    def create_share(bean:, selected_photo_attachment_ids:, password: nil, enabled: true)
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled:,
        password:,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end

    def public_bean_media_handle_for(share, attachment_id)
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        Rails.application.key_generator.generate_key("public-bean-share-media-handle"),
        "#{share.token}:#{attachment_id}"
      ).first(32)
    end
end
