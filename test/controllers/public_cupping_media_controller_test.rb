require "test_helper"

class PublicCuppingMediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cupping_request = cupping_requests(:guest_espresso)
    @brew = @cupping_request.brew
    @brew.update!(recipient_kind: "guest", recipient_name: "Private Guest")
  end

  test "streams only snapshotted currently authorized identity media through opaque request-specific handles" do
    avatar = attach_named_photo(@brew.user, :avatar, filename: "private-original-name.jpg")
    @cupping_request.refresh_snapshot!
    handle = @cupping_request.public_media_handle_for(avatar.id)

    assert handle.present?
    assert_no_match(/#{avatar.id}/, handle)

    get public_cupping_media_path(@cupping_request.token, handle)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match "public-cupping-media", response.headers["Content-Disposition"]
    assert_no_match(/private-original-name\.jpg|#{avatar.id}/, response.headers["Content-Disposition"])

    get public_cupping_media_path(@cupping_request.token, handle, variant: "thumbnail")
    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
    assert_match "public-cupping-thumbnail", response.headers["Content-Disposition"]
  end

  test "the same identity attachment receives a different handle for another cupping request" do
    avatar = attach_named_photo(@brew.user, :avatar)
    @cupping_request.refresh_snapshot!
    second_brew = @brew.dup
    second_brew.occurred_at = 1.minute.from_now
    second_brew.save!
    second_request = CuppingRequests::Synchronize.call(second_brew)

    assert_not_equal @cupping_request.public_media_handle_for(avatar.id), second_request.public_media_handle_for(avatar.id)
  end

  test "rejects numeric guesses forged record-photo handles unknown tokens and variants" do
    avatar = attach_named_photo(@brew.user, :avatar)
    private_photo = attach_photo(@brew)
    @cupping_request.refresh_snapshot!
    avatar_handle = @cupping_request.public_media_handle_for(avatar.id)
    forged_photo_handle = @cupping_request.send(:media_handle_for_attachment_id, private_photo.id)

    get public_cupping_media_path(@cupping_request.token, avatar.id)
    assert_response :not_found

    get public_cupping_media_path(@cupping_request.token, forged_photo_handle)
    assert_response :not_found

    get public_cupping_media_path("missing-token", avatar_handle)
    assert_response :not_found

    get public_cupping_media_path(@cupping_request.token, avatar_handle, variant: "large")
    assert_response :not_found
  end

  test "rejects unsafe browser-active media even when it is in the snapshot manifest" do
    @brew.user.avatar.attach(
      io: StringIO.new("<html><script>alert('unsafe')</script></html>"),
      filename: "payload.html",
      content_type: "text/html"
    )
    attachment = @brew.user.avatar.attachment
    @cupping_request.refresh_snapshot!

    get public_cupping_media_path(
      @cupping_request.token,
      @cupping_request.public_media_handle_for(attachment.id)
    )

    assert_response :not_found
    assert_empty response.body
  end

  test "replacing an identity image immediately revokes the stale handle until snapshot refresh" do
    old_avatar = attach_named_photo(@brew.user, :avatar, filename: "old.jpg")
    @cupping_request.refresh_snapshot!
    old_handle = @cupping_request.public_media_handle_for(old_avatar.id)

    new_avatar = attach_named_photo(@brew.user, :avatar, filename: "new.jpg")

    get public_cupping_media_path(@cupping_request.token, old_handle)
    assert_response :not_found

    forged_new_handle = @cupping_request.send(:media_handle_for_attachment_id, new_avatar.id)
    get public_cupping_media_path(@cupping_request.token, forged_new_handle)
    assert_response :not_found
  end
end
