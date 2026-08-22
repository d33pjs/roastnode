require "test_helper"

class PublicRecipeMediaControllerTest < ActionDispatch::IntegrationTest
  test "serves selected recipe photo through opaque handle" do
    share, photo = create_share_with_photo(enabled: true)

    assert_no_difference -> { ActivityEvent.count } do
      get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id), variant: "thumbnail")
    end

    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
  end

  test "does not serve unselected recipe photo" do
    share, photo = create_share_with_photo(enabled: true, selected: false)

    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id) || "missing")

    assert_response :not_found
  end

  test "password protected share gates selected recipe media" do
    share, photo = create_share_with_photo(enabled: true, password: "espresso")

    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id))
    assert_response :not_found

    post unlock_public_recipe_page_path(share.token), params: { password: "espresso" }
    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id))
    assert_response :success
  end

  test "rejects selected unsafe public recipe media content type" do
    share, attachment = create_share_with_payload(content_type: "text/html")

    get public_recipe_media_path(share.token, share.public_media_handle_for(attachment.id))

    assert_response :not_found
  end

  private
    def create_share_with_photo(enabled:, selected: true, password: nil)
      recipe = recipes(:household_recipe)
      recipe.photos.attach(
        io: file_fixture("photo.jpg").open,
        filename: "photo.jpg",
        content_type: "image/jpeg"
      )
      photo = recipe.photos.attachments.first
      selected_ids = selected ? [ photo.id ] : []
      share = recipe.create_public_recipe_share!(
        workspace: recipe.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared recipe",
        enabled:,
        password:,
        selected_photo_attachment_ids: selected_ids,
        snapshot: PublicRecipeShareSnapshotBuilder.new(
          recipe:,
          title: "Shared recipe",
          selected_photo_attachment_ids: selected_ids
        ).call
      )
      [ share, photo ]
    end

    def create_share_with_payload(content_type:)
      recipe = recipes(:household_recipe)
      recipe.photos.attach(
        io: StringIO.new("<html><script>alert(1)</script></html>"),
        filename: "payload.html",
        content_type:
      )
      attachment = recipe.photos.attachments.last
      selected_ids = [ attachment.id ]
      share = recipe.create_public_recipe_share!(
        workspace: recipe.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared recipe",
        enabled: true,
        selected_photo_attachment_ids: selected_ids,
        snapshot: PublicRecipeShareSnapshotBuilder.new(
          recipe:,
          title: "Shared recipe",
          selected_photo_attachment_ids: selected_ids
        ).call
      )
      [ share, attachment ]
    end
end
