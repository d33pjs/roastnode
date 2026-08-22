require "test_helper"

class PublicBrewMediaControllerTest < ActionDispatch::IntegrationTest
  test "streams selected public photo from enabled share" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ])

    assert_no_difference -> { ActivityEvent.count } do
      get public_media_path_for(share, photo)
    end
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match "public-brew-media", response.headers["Content-Disposition"]
    assert_no_match "photo.jpg", response.headers["Content-Disposition"]
    assert_no_match photo.id.to_s, response.headers["Content-Disposition"]

    get public_media_path_for(share, photo, variant: "thumbnail")
    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
    assert_match "public-brew-thumbnail", response.headers["Content-Disposition"]
    assert_no_match photo.id.to_s, response.headers["Content-Disposition"]

    get public_media_path_for(share, photo, variant: "hero")
    assert_response :success
    assert_equal "hero", response.headers["X-Roastnode-Media-Variant"]
    assert_match "public-brew-hero", response.headers["Content-Disposition"]
    assert_no_match "photo.jpg", response.headers["Content-Disposition"]
    assert_no_match photo.id.to_s, response.headers["Content-Disposition"]
  end

  test "rejects unselected photo" do
    brew = brews(:morning_espresso)
    selected = attach_photo(brew)
    unselected = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ selected.id ])
    forged_handle = share.send(:media_handle_for_attachment_id, unselected.id)

    get public_brew_media_path(share.token, forged_handle)

    assert_response :not_found
  end

  test "rejects numeric attachment id guesses" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_brew_media_path(share.token, photo.id)

    assert_response :not_found
  end

  test "rejects media for disabled share and missing token" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: false, selected_photo_attachment_ids: [ photo.id ])

    get public_media_path_for(share, photo)
    assert_response :not_found

    get public_brew_media_path("missing-token", share.public_media_handle_for(photo.id))
    assert_response :not_found
  end

  test "rejects media for stale enabled quick drip share" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ])
    path = public_media_path_for(share, photo)
    quick_drip = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral"
    )
    share.update_columns(brew_id: quick_drip.id)

    get path

    assert_response :not_found
  end

  test "rejects unknown public media variant" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_media_path_for(share, photo, variant: "large")

    assert_response :not_found
  end

  test "rejects selected unsafe public brew media content type" do
    brew = brews(:morning_espresso)
    attachment = attach_payload(brew, filename: "payload.html", content_type: "text/html")
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ attachment.id ])

    get public_media_path_for(share, attachment)

    assert_response :not_found

    get public_media_path_for(share, attachment, variant: "hero")
    assert_response :not_found
  end

  test "rejects media for password protected share until unlocked" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ], password: "espresso")

    get public_media_path_for(share, photo)
    assert_response :not_found

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    get public_media_path_for(share, photo)
    assert_response :success
  end

  test "password change invalidates existing public media unlock" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [ photo.id ], password: "espresso")

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    get public_media_path_for(share, photo)
    assert_response :success

    share.update!(password: "ristretto")

    get public_media_path_for(share, photo)
    assert_response :not_found
  end

  test "recipient avatar handle is revoked immediately when workspace membership ends" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [])
    path = public_media_path_for(share, avatar, variant: "thumbnail")

    get path
    assert_response :success

    memberships(:member).destroy!

    get path
    assert_response :not_found
  end

  test "replacing a recipient avatar invalidates the old handle without exposing the new avatar before refresh" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    old_avatar = attach_named_photo(users(:two), :avatar, filename: "old-petra.jpg")
    share = create_share(brew:, enabled: true, selected_photo_attachment_ids: [])
    old_path = public_media_path_for(share, old_avatar, variant: "thumbnail")

    new_avatar = attach_named_photo(users(:two), :avatar, filename: "new-petra.jpg")

    get old_path
    assert_response :not_found

    forged_new_handle = share.send(:media_handle_for_attachment_id, new_avatar.id)
    get public_brew_media_path(share.token, forged_new_handle, variant: "thumbnail")
    assert_response :not_found
  end

  private
    def public_media_path_for(share, attachment, variant: nil)
      public_brew_media_path(share.token, share.public_media_handle_for(attachment.id), variant:)
    end

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

    def attach_payload(record, filename:, content_type:)
      record.photos.attach(
        io: StringIO.new("<html><script>alert(1)</script></html>"),
        filename:,
        content_type:
      )
      record.photos.attachments.last
    end
end
