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

  test "serves thumbnail variant through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get media_attachment_path(attachment, variant: :thumbnail)

    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
    assert_match "inline", response.headers["Content-Disposition"]
    assert_match "thumbnail-photo.jpg", response.headers["Content-Disposition"]
  end

  test "does not serve unsupported media variant" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get media_attachment_path(attachment, variant: :poster)

    assert_response :not_found
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

  test "serves avatar for a user in the active workspace" do
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    attachment = attach_named_photo(users(:one), :avatar, filename: "avatar.jpg")

    get media_attachment_path(attachment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "does not serve avatar for an unrelated user" do
    sign_in_as(users(:one))
    other_user = User.create!(email_address: "outsider@example.com", password: "password")
    attachment = attach_named_photo(other_user, :avatar, filename: "avatar.jpg")

    get media_attachment_path(attachment)

    assert_response :not_found
  end

  test "serves active workspace logo" do
    sign_in_as(users(:one))
    attachment = attach_named_photo(workspaces(:household), :logo, filename: "logo.jpg")

    get media_attachment_path(attachment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "does not serve another workspace logo" do
    sign_in_as(users(:one))
    attachment = attach_named_photo(workspaces(:other_household), :logo, filename: "logo.jpg")

    get media_attachment_path(attachment)

    assert_response :not_found
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

  test "writer opens crop editor for an active workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get crop_media_attachment_path(attachment)

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment)
    assert_select "input[type=file][name=?]", "crop[file]"
    assert_select "input[type=radio][name=?][value=?]", "crop[mode]", "new"
    assert_select "input[type=radio][name=?][value=?]", "crop[mode]", "overwrite"
  end

  test "viewer cannot open crop editor" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    attachment = attach_photo(beans(:open_household))

    get crop_media_attachment_path(attachment)

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
  ensure
    memberships(:member)&.update!(role: "member")
  end

  test "writer saves cropped image as a new primary attachment" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    original = attach_photo(bean)

    assert_difference -> { bean.photos.attachments.reload.count }, 1 do
      patch crop_media_attachment_path(original), params: {
        crop: {
          file: photo_upload(filename: "cropped.jpg"),
          mode: "new",
          primary: "1"
        }
      }
    end

    new_attachment = bean.photos.attachments.order(:id).last
    assert_redirected_to bean_path(bean)
    assert_equal I18n.t("media_attachments.crop.created"), flash[:notice]
    assert_equal new_attachment.id, bean.reload.primary_photo_attachment_id
    assert ActiveStorage::Attachment.exists?(original.id)
  end

  test "writer overwrites an attachment with a cropped image and preserves primary" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    original = attach_photo(bean)
    bean.set_primary_photo!(original)

    assert_no_difference -> { bean.photos.attachments.reload.count } do
      patch crop_media_attachment_path(original), params: {
        crop: {
          file: photo_upload(filename: "replacement.jpg"),
          mode: "overwrite"
        }
      }
    end

    new_attachment = bean.photos.attachments.order(:id).last
    assert_redirected_to bean_path(bean)
    assert_equal I18n.t("media_attachments.crop.updated"), flash[:notice]
    assert_equal new_attachment.id, bean.reload.primary_photo_attachment_id
    assert_not ActiveStorage::Attachment.exists?(original.id)
  end

  test "writer cannot crop another workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    patch crop_media_attachment_path(attachment), params: {
      crop: {
        file: photo_upload(filename: "cropped.jpg"),
        mode: "new"
      }
    }

    assert_response :not_found
  end

  test "writer removes an active workspace attachment" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    attachment = attach_photo(bean)
    share = create_public_brew_share_for(brews(:morning_espresso), selected_photo_attachment_ids: [ attachment.id ])
    assert_includes share.public_attachment_ids, attachment.id

    assert_difference -> { bean.photos.attachments.reload.count }, -1 do
      delete media_attachment_path(attachment)
    end

    assert_redirected_to bean_path(bean)
    assert_equal I18n.t("media_attachments.destroy.destroyed"), flash[:notice]
    assert_not_includes share.reload.selected_photo_attachment_ids, attachment.id
    assert_not_includes share.public_attachment_ids, attachment.id
  end

  test "removing selected bean photo refreshes public bean media allowlist" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    attachment = attach_photo(bean)
    share = create_public_bean_share_for(bean, selected_photo_attachment_ids: [ attachment.id ])
    media_path = public_bean_media_path(share.token, share.public_media_handle_for(attachment.id))

    assert_difference -> { bean.photos.attachments.reload.count }, -1 do
      delete media_attachment_path(attachment)
    end

    assert_redirected_to bean_path(bean)
    assert_not_includes share.reload.selected_photo_attachment_ids, attachment.id
    assert_not_includes share.public_attachment_ids, attachment.id

    get media_path
    assert_response :not_found
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

  test "member cannot manage equipment photo attachments" do
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    equipment = equipment(:household_grinder)
    attachment = attach_photo(equipment)

    get equipment_path(equipment)
    assert_response :success
    assert_select "a[href=?]", media_attachment_path(attachment), text: I18n.t("shared.photo_grid.view")
    assert_select "a[href=?]", download_media_attachment_path(attachment), text: I18n.t("shared.photo_grid.download")
    assert_select "a[href=?]", crop_media_attachment_path(attachment), count: 0
    assert_select "form[action='#{primary_media_attachment_path(attachment)}']", count: 0
    assert_select "form[action='#{media_attachment_path(attachment)}']", count: 0

    get crop_media_attachment_path(attachment)
    assert_redirected_to root_path

    patch primary_media_attachment_path(attachment)
    assert_redirected_to root_path
    assert_nil equipment.reload.primary_photo_attachment_id

    assert_no_difference -> { equipment.photos.attachments.reload.count } do
      delete media_attachment_path(attachment)
    end
    assert_redirected_to root_path
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
    assert_select "[data-controller~=?]", "photo-lightbox"
    assert_select "[data-photo-lightbox-sources-value]"
    assert_select "a[href=?]", media_attachment_path(attachment), text: I18n.t("shared.photo_grid.view")
    assert_select "button[data-action=?][data-full-src=?]", "photo-lightbox#open", media_attachment_path(attachment)
    assert_select "img[src=?][class*=object-contain]", media_attachment_path(attachment, variant: :thumbnail)
    assert_select "[data-photo-lightbox-target=?][role=dialog]", "dialog"
    assert_select "a[href=?]", download_media_attachment_path(attachment), text: I18n.t("shared.photo_grid.download")
    assert_select "span", text: I18n.t("shared.photo_grid.primary")
    assert_select "a[href=?]", crop_media_attachment_path(attachment), text: I18n.t("shared.photo_grid.crop")
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
    assert_select "a[href=?]", crop_media_attachment_path(attachment), count: 0
    assert_select "form[action='#{primary_media_attachment_path(second)}']", count: 0
    assert_select "form[action='#{media_attachment_path(attachment)}']", count: 0
  ensure
    memberships(:owner)&.update!(role: "owner")
  end

  private
    def create_public_brew_share_for(brew, selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids:
        ).call
      )
    end

    def create_public_bean_share_for(bean, selected_photo_attachment_ids: [])
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end

end
