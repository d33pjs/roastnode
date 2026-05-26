require "test_helper"

class MediaAttachmentsControllerTest < ActionDispatch::IntegrationTest
  test "serves active workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get media_attachment_path(attachment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match "inline", response.headers["Content-Disposition"]
  end

  test "downloads active workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get download_media_attachment_path(attachment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match attachment.blob.filename.to_s, response.headers["Content-Disposition"]
  end

  test "does not download another workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    get download_media_attachment_path(attachment)

    assert_response :not_found
  end

  test "does not serve another workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    get media_attachment_path(attachment)

    assert_response :not_found
  end

  test "writer removes an active workspace attachment" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    attachment = attach_photo(bean)

    assert_difference -> { bean.photos.attachments.reload.count }, -1 do
      delete media_attachment_path(attachment)
    end

    assert_redirected_to bean_path(bean)
    assert_equal I18n.t("media_attachments.destroy.destroyed"), flash[:notice]
  end

  test "writer marks an active workspace attachment as primary" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    first = attach_photo(bean)
    second = attach_photo(bean)

    patch primary_media_attachment_path(second)

    assert_redirected_to bean_path(bean)
    assert_equal second.id, bean.reload.primary_photo_attachment_id
    assert_equal second, bean.primary_photo_attachment
    assert_not_equal first, bean.primary_photo_attachment
  end

  test "viewer cannot mark an attachment as primary" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    bean = beans(:open_household)
    attachment = attach_photo(bean)

    patch primary_media_attachment_path(attachment)

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
    assert_nil bean.reload.primary_photo_attachment_id
  end

  test "writer cannot mark another workspace attachment as primary" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    patch primary_media_attachment_path(attachment)

    assert_response :not_found
  end

  test "writer returns to referring edit page after removing an attachment" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    attachment = attach_photo(brew)

    delete media_attachment_path(attachment), headers: { "HTTP_REFERER" => edit_brew_url(brew) }

    assert_redirected_to edit_brew_path(brew)
  end

  test "viewer cannot remove an active workspace attachment" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    bean = beans(:open_household)
    attachment = attach_photo(bean)

    assert_no_difference -> { bean.photos.attachments.reload.count } do
      delete media_attachment_path(attachment)
    end

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
  end

  test "writer cannot remove another workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    assert_no_difference -> { ActiveStorage::Attachment.count } do
      delete media_attachment_path(attachment)
    end

    assert_response :not_found
  end

  test "photo grid shows delete controls only to writers" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get bean_path(beans(:open_household))

    assert_response :success
    assert_select "a[href=?]", media_attachment_path(attachment), text: I18n.t("shared.photo_grid.view")
    assert_select "a[href=?]", download_media_attachment_path(attachment), text: I18n.t("shared.photo_grid.download")
    assert_select "span", text: I18n.t("shared.photo_grid.primary")
    assert_select "form[action='#{media_attachment_path(attachment)}'] button", text: I18n.t("shared.photo_grid.delete")

    second = attach_photo(beans(:open_household))
    get bean_path(beans(:open_household))

    assert_response :success
    assert_select "form[action='#{primary_media_attachment_path(second)}'] button", text: I18n.t("shared.photo_grid.make_primary")

    memberships(:owner).update!(role: "viewer")
    get bean_path(beans(:open_household))

    assert_response :success
    assert_select "a[href=?]", media_attachment_path(attachment), text: I18n.t("shared.photo_grid.view")
    assert_select "a[href=?]", download_media_attachment_path(attachment), text: I18n.t("shared.photo_grid.download")
    assert_select "form[action='#{primary_media_attachment_path(second)}']", count: 0
    assert_select "form[action='#{media_attachment_path(attachment)}']", count: 0
  ensure
    memberships(:owner)&.update!(role: "owner")
  end
end
