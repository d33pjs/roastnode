require "test_helper"
require "vips"

class MediaAttachmentsControllerTest < ActionDispatch::IntegrationTest
  test "primary crop and remove emit one parent media event without attachment internals" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    first = attach_photo(bean)
    second = attach_photo(bean)

    events = []
    events << assert_activity_event(
      action: "bean.media_updated", workspace: bean.workspace, actor: users(:one), subject: bean
    ) do
      patch primary_media_attachment_path(second)
    end
    events << assert_activity_event(
      action: "bean.media_updated", workspace: bean.workspace, actor: users(:one), subject: bean
    ) do
      patch crop_media_attachment_path(second), params: {
        crop: { file: photo_upload(filename: "cropped.jpg"), mode: "new", primary: "1" }
      }
    end
    events << assert_activity_event(
      action: "bean.media_updated", workspace: bean.workspace, actor: users(:one), subject: bean
    ) do
      delete media_attachment_path(first)
    end

    events.each do |event|
      assert_equal %w[actor_kind actor_label record_kind subject_label status].sort, event.metadata.keys.sort
      assert_no_match(/attachment|filename|rails\/active_storage|media_attachments/i, event.metadata.to_json)
    end
  end

  test "media removal emits the owning parent event for every supported parent type" do
    sign_in_as(users(:one))
    external_coffee = ExternalCoffee.create!(
      workspace: workspaces(:household), user: users(:one), drink_type: "Flat White"
    )
    bean = beans(:open_household)
    bean_attachment = attach_photo(bean)
    assert_activity_event(action: "bean.media_updated", workspace: bean.workspace, actor: users(:one), subject: bean) do
      delete media_attachment_path(bean_attachment)
    end

    brew = brews(:morning_espresso)
    brew_attachment = attach_photo(brew)
    assert_activity_event(action: "brew.media_updated", workspace: brew.workspace, actor: users(:one), subject: brew) do
      delete media_attachment_path(brew_attachment)
    end

    coffee_attachment = attach_photo(external_coffee)
    assert_activity_event(action: "external_coffee.media_updated", workspace: external_coffee.workspace, actor: users(:one), subject: external_coffee) do
      delete media_attachment_path(coffee_attachment)
    end

    equipment = equipment(:household_grinder)
    equipment_attachment = attach_photo(equipment)
    assert_activity_event(action: "equipment.media_updated", workspace: equipment.workspace, actor: users(:one), subject: equipment) do
      delete media_attachment_path(equipment_attachment)
    end

    preparation_tool = preparation_tools(:wdt)
    tool_attachment = attach_photo(preparation_tool)
    assert_activity_event(action: "preparation_tool.media_updated", workspace: preparation_tool.workspace, actor: users(:one), subject: preparation_tool) do
      delete media_attachment_path(tool_attachment)
    end

    equipment_event = equipment_events(:grinder_cleaning)
    event_attachment = attach_photo(equipment_event)
    assert_activity_event(action: "equipment_event.media_updated", workspace: equipment_event.workspace, actor: users(:one), subject: equipment_event) do
      delete media_attachment_path(event_attachment)
    end

    recipe = recipes(:household_recipe)
    recipe_attachment = attach_photo(recipe)
    assert_activity_event(action: "recipe.media_updated", workspace: recipe.workspace, actor: users(:one), subject: recipe) do
      delete media_attachment_path(recipe_attachment)
    end

    workspace = workspaces(:household)
    logo = attach_named_photo(workspace, :logo)
    assert_activity_event(
      action: "workspace.media_updated", workspace:, actor: users(:one), subject: workspace
    ) do
      delete media_attachment_path(logo)
    end

    user = users(:one)
    avatar = attach_named_photo(user, :avatar)
    assert_activity_event(
      action: "profile.media_updated", workspace: workspaces(:household), actor: user, subject: user
    ) do
      delete media_attachment_path(avatar)
    end
  end

  test "media reads do not emit activity" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    assert_no_difference -> { ActivityEvent.count } do
      get media_attachment_path(attachment)
      assert_response :success
      get download_media_attachment_path(attachment)
      assert_response :success
    end
  end

  test "public refresher failure rolls back primary media change snapshot writes and activity" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    first = attach_photo(bean)
    second = attach_photo(bean)
    bean.set_primary_photo!(first)
    share = create_public_bean_share_for(bean, selected_photo_attachment_ids: [ first.id, second.id ])
    original_snapshot = share.snapshot.deep_dup
    failing_refresh = lambda do |_record|
      share.update!(snapshot: share.snapshot.merge("rollback_marker" => "media"))
      raise "public bean refresh failed"
    end

    assert_no_difference -> { ActivityEvent.count } do
      with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_for, failing_refresh) do
        assert_raises(RuntimeError) { patch primary_media_attachment_path(second) }
      end
    end

    assert_equal first.id, bean.reload.primary_photo_attachment_id
    assert_equal original_snapshot, share.reload.snapshot
  end

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

  test "hero variant is bounded without crop semantics" do
    assert_equal "hero", MediaAttachmentsController::HERO_VARIANT
    assert_equal({ resize_to_limit: [ 1200, 1200 ] }, MediaAttachmentsController::HERO_TRANSFORMATIONS)
    assert_not_includes MediaAttachmentsController::HERO_TRANSFORMATIONS.keys, :resize_to_fill
    sign_in_as(users(:one))
    attachment = attach_large_raster(beans(:open_household))

    get media_attachment_path(attachment, variant: :hero)

    assert_response :success
    assert_equal "hero", response.headers["X-Roastnode-Media-Variant"]
    assert_match "inline", response.headers["Content-Disposition"]
    assert_match "hero-large-photo.png", response.headers["Content-Disposition"]
    hero = Vips::Image.new_from_buffer(response.body, "")
    assert_equal 1200, [ hero.width, hero.height ].max
  end

  test "processes a valid large image into a bounded Vips thumbnail" do
    sign_in_as(users(:one))
    attachment = nil
    File.open(Rails.root.join("app/assets/images/brand/logo_mark_transparent.png")) do |file|
      beans(:open_household).photos.attach(
        io: file,
        filename: "large-photo.png",
        content_type: "image/png"
      )
      attachment = beans(:open_household).photos.attachments.last
    end

    get media_attachment_path(attachment, variant: :thumbnail)

    assert_response :success
    thumbnail = Vips::Image.new_from_buffer(response.body, "")
    assert_equal 480, [ thumbnail.width, thumbnail.height ].max
    assert_not_equal attachment.blob.download, response.body
  end

  test "does not serve unsupported media variant" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get media_attachment_path(attachment, variant: :poster)

    assert_response :not_found
  end

  test "does not serve active workspace attachment with unsafe content type" do
    sign_in_as(users(:one))
    attachment = attach_payload(beans(:open_household), filename: "payload.html", content_type: "text/html")

    get media_attachment_path(attachment)
    assert_response :not_found

    get download_media_attachment_path(attachment)
    assert_response :not_found

    get media_attachment_path(attachment, variant: :hero)
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

    def attach_payload(record, filename:, content_type:)
      record.photos.attach(
        io: StringIO.new("<html><script>alert(1)</script></html>"),
        filename:,
        content_type:
      )
      record.photos.attachments.last
    end

    def attach_large_raster(record)
      File.open(Rails.root.join("app/assets/images/brand/logo_only_white_bg.png")) do |file|
        record.photos.attach(
          io: file,
          filename: "large-photo.png",
          content_type: "image/png"
        )
      end
      record.photos.attachments.last
    end
end
