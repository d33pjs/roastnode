require "test_helper"

class PublicRecipeSharesControllerTest < ActionDispatch::IntegrationTest
  test "writer can open new share form for own recipe" do
    sign_in_as(users(:one))

    get new_recipe_public_recipe_share_path(recipes(:household_recipe))

    assert_response :success
    assert_select "h1", I18n.t("public_recipe_shares.new.title")
    assert_select "input[type=checkbox][name=?]", "public_recipe_share[enabled]"
    assert_select "input[name=?]", "public_recipe_share[title]"
    assert_select "input[type=password][name=?]", "public_recipe_share[password]"
    assert_select "input[type=file]", count: 0
  end

  test "share form can select recipe photo but does not include it by default" do
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    photo = recipe.photos.attachments.first
    sign_in_as(users(:one))

    get new_recipe_public_recipe_share_path(recipe)

    assert_response :success
    assert_select "input[type=checkbox][name=?][value=?]", "public_recipe_share[selected_photo_attachment_ids][]", photo.id.to_s
    assert_select "input[type=checkbox][name=?][value=?][checked]", "public_recipe_share[selected_photo_attachment_ids][]", photo.id.to_s, count: 0
  end

  test "share form only offers the primary recipe photo" do
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "primary-photo.jpg",
      content_type: "image/jpeg"
    )
    primary = recipe.photos.attachments.first
    recipe.set_primary_photo!(primary)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "legacy-extra-photo.jpg",
      content_type: "image/jpeg"
    )
    legacy_extra = recipe.photos.attachments.order(:id).last
    sign_in_as(users(:one))

    get new_recipe_public_recipe_share_path(recipe)

    assert_response :success
    assert_select "input[type=checkbox][name=?][value=?]", "public_recipe_share[selected_photo_attachment_ids][]", primary.id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "public_recipe_share[selected_photo_attachment_ids][]", legacy_extra.id.to_s, count: 0
  end

  test "writer creates disabled password protected recipe share snapshot" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)

    assert_difference -> { PublicRecipeShare.count }, 1 do
      post recipe_public_recipe_share_path(recipe), params: {
        public_recipe_share: {
          enabled: "0",
          title: "Shared recipe",
          password: "espresso"
        }
      }
    end

    share = recipe.reload.public_recipe_share
    assert_redirected_to edit_recipe_public_recipe_share_path(recipe)
    assert_equal "Shared recipe", share.title
    assert_not share.enabled?
    assert share.password_protected?
    assert_equal users(:one), share.created_by
    assert_equal users(:one), share.updated_by
    assert_equal "18.0", share.snapshot.dig("recipe", "targets", "dose_grams")
  end

  test "post to existing share updates without creating duplicate" do
    recipe = recipes(:household_recipe)
    share = create_share_for(recipe, title: "Old recipe")
    sign_in_as(users(:one))

    assert_no_difference -> { PublicRecipeShare.count } do
      post recipe_public_recipe_share_path(recipe), params: {
        public_recipe_share: {
          enabled: "1",
          title: "Updated recipe"
        }
      }
    end

    assert_equal share.id, recipe.reload.public_recipe_share.id
    assert_equal "Updated recipe", share.reload.title
    assert share.enabled?
  end

  test "member cannot manage another writers recipe share" do
    users(:two).update!(active_workspace: workspaces(:household))
    create_share_for(recipes(:household_recipe), user: users(:one))
    sign_in_as(users(:two))

    get edit_recipe_public_recipe_share_path(recipes(:household_recipe))

    assert_redirected_to root_path
  end

  test "owner can manage another users recipe share" do
    users(:two).update!(active_workspace: workspaces(:household))
    recipe = create_recipe_for(users(:two))
    share = create_share_for(recipe, user: users(:two))
    sign_in_as(users(:one))

    get edit_recipe_public_recipe_share_path(recipe)

    assert_response :success
    assert_select "h1", I18n.t("public_recipe_shares.edit.title")
    assert_select "input[name=?][value=?]", "public_recipe_share[title]", share.title
  end

  test "viewer cannot manage public recipe shares" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))

    get new_recipe_public_recipe_share_path(recipes(:household_recipe))

    assert_redirected_to root_path
  end

  test "update can enable share and clear password" do
    recipe = recipes(:household_recipe)
    share = create_share_for(recipe, enabled: false, password: "espresso")
    assert share.password_protected?
    sign_in_as(users(:one))

    patch recipe_public_recipe_share_path(recipe), params: {
      public_recipe_share: {
        enabled: "1",
        title: "Enabled recipe",
        password: "",
        clear_password: "1"
      }
    }

    assert_redirected_to edit_recipe_public_recipe_share_path(recipe)
    share.reload
    assert share.enabled?
    assert_equal "Enabled recipe", share.title
    assert_not share.password_protected?
  end

  test "update stores only selected recipe-owned public photo" do
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    selected = recipe.photos.attachments.first
    unrelated_record = beans(:open_household)
    unrelated_record.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    unrelated = unrelated_record.photos.attachments.first
    create_share_for(recipe, enabled: false)
    sign_in_as(users(:one))

    patch recipe_public_recipe_share_path(recipe), params: {
      public_recipe_share: {
        enabled: "1",
        title: "Photo recipe",
        selected_photo_attachment_ids: [ selected.id, unrelated.id ]
      }
    }

    share = recipe.reload.public_recipe_share
    assert_redirected_to edit_recipe_public_recipe_share_path(recipe)
    assert_equal [ selected.id ], share.selected_photo_attachment_ids
    assert_equal selected.id, share.snapshot.dig("recipe", "photo", "attachment_id")
  end

  test "writer can destroy own public recipe share" do
    recipe = recipes(:household_recipe)
    create_share_for(recipe)
    sign_in_as(users(:one))

    assert_difference -> { PublicRecipeShare.count }, -1 do
      delete recipe_public_recipe_share_path(recipe)
    end

    assert_redirected_to recipe_path(recipe)
  end

  private
    def create_recipe_for(user)
      workspaces(:household).recipes.create!(
        created_by: user,
        source_brew: brews(:morning_espresso),
        title: "Member recipe",
        method: "espresso",
        profile: recipes(:household_recipe).profile,
        source_snapshot: recipes(:household_recipe).source_snapshot
      )
    end

    def create_share_for(recipe, user: users(:one), enabled: true, password: nil, title: "Shared recipe")
      recipe.create_public_recipe_share!(
        workspace: recipe.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title:,
        password:,
        snapshot: PublicRecipeShareSnapshotBuilder.new(recipe:, title:).call
      )
    end
end
