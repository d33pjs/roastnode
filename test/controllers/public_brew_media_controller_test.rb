require "test_helper"

class PublicBrewMediaControllerTest < ActionDispatch::IntegrationTest
  test "streams selected public photo from enabled share" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_brew_media_path(share.token, photo)
    assert_response :success
    assert_equal "image/jpeg", response.media_type

    get public_brew_media_path(share.token, photo, variant: "thumbnail")
    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
  end

  test "rejects unselected photo" do
    brew = brews(:morning_espresso)
    selected = attach_photo(brew)
    unselected = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ selected.id ])

    get public_brew_media_path(share.token, unselected)

    assert_response :not_found
  end

  test "rejects media for password protected share until unlocked" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ], password: "espresso")

    get public_brew_media_path(share.token, photo)
    assert_response :not_found

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    get public_brew_media_path(share.token, photo)
    assert_response :success
  end

  private
    def create_share(brew:, enabled:, selected_photo_attachment_ids:, password: nil)
      snapshot = PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Shared shot",
        selected_photo_attachment_ids:
      ).call

      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared shot",
        enabled:,
        password:,
        selected_photo_attachment_ids:,
        snapshot:
      )
    end
end
