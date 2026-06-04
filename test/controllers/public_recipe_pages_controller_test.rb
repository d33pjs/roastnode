require "test_helper"

class PublicRecipePagesControllerTest < ActionDispatch::IntegrationTest
  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_recipe_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without authentication" do
    share = create_share(enabled: true)
    share.workspace.update!(buy_me_a_coffee_url: "https://buymeacoffee.com/roastnode")

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-recipe-page]"
    assert_select "[data-testid=public-recipe-target-guide]", text: /Set grinder/
    assert_select "body", text: /Shared recipe/
    assert_select "body", text: /Public source note/
    assert_select "a[href='https://example.test/recipe'][data-testid=public-recipe-link]", text: "Recipe writeup"
    assert_select "body", text: /Private recipe link/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "[data-testid=site-footer-github-logo]"
    assert_select "[data-testid=site-footer-version]", count: 0
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
    assert_select "[data-testid=site-footer-buy-me-a-coffee-logo]"
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
    assert_no_match "attachment_id", response.body
  end

  test "enabled share renders official buy me a coffee badge script when configured" do
    share = create_share(enabled: true)
    share.workspace.update!(
      buy_me_a_coffee_display_mode: "official_badge",
      buy_me_a_coffee_slug: "d33p.js",
      buy_me_a_coffee_text: "Buy me a coffee"
    )

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "script[data-testid=site-footer-buy-me-a-coffee][src=?]", "https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js"
    assert_select "script[data-name=?]", "bmc-button"
    assert_select "script[data-slug=?]", "d33p.js"
    assert_select "script[data-text=?]", "Buy me a coffee"
    assert_select "script[data-color=?]", "#986338"
    assert_select "script[data-font=?]", "Comic"
    assert_select "script[data-outline-color=?]", "#ffffff"
    assert_select "script[data-font-color=?]", "#ffffff"
    assert_select "script[data-coffee-color=?]", "#FFDD00"
    assert_select "[data-testid=site-footer-version]", count: 0
  end

  test "enabled share renders public ingredients and finish note" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" }
    ]
    profile["finish_note"] = "Pour espresso over matcha."
    recipe.update!(profile:)
    share = recipe.create_public_recipe_share!(
      workspace: recipe.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      title: "Shared recipe",
      enabled: true,
      snapshot: PublicRecipeShareSnapshotBuilder.new(recipe:, title: "Shared recipe", selected_photo_attachment_ids: []).call
    )

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-recipe-finish]", text: /200 ml matcha/
    assert_select "[data-testid=public-recipe-finish]", text: /Pour espresso over matcha/
  end

  test "enabled share renders selected recipe photo with opaque public media url" do
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    photo = recipe.photos.attachments.first
    share = recipe.create_public_recipe_share!(
      workspace: recipe.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      title: "Shared recipe",
      enabled: true,
      selected_photo_attachment_ids: [ photo.id ],
      snapshot: PublicRecipeShareSnapshotBuilder.new(recipe:, title: "Shared recipe", selected_photo_attachment_ids: [ photo.id ]).call
    )

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "img[data-testid=public-recipe-photo][src^=?]", "/r/#{share.token}/media/"
    assert_no_match "attachment_id", response.body
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "password protected share shows gate until unlocked" do
    share = create_share(enabled: true, password: "espresso")

    get public_recipe_page_path(share.token)
    assert_response :success
    assert_select "form[action=?]", unlock_public_recipe_page_path(share.token)
    assert_select "[data-testid=public-recipe-page]", count: 0

    post unlock_public_recipe_page_path(share.token), params: { password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "body", text: /#{I18n.t("public_recipe_pages.unlock.failed")}/

    post unlock_public_recipe_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_recipe_page_path(share.token)

    get public_recipe_page_path(share.token)
    assert_response :success
    assert_select "[data-testid=public-recipe-page]"
  end

  test "sparse stale snapshot renders with public fallbacks" do
    share = create_share(enabled: true)
    share.update!(snapshot: {
      "title" => "Sparse recipe",
      "recipe" => {
        "targets" => {},
        "source_brew" => {}
      }
    })

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-recipe-page]"
    assert_select "body", text: /Sparse recipe/
    assert_select "body", text: /#{I18n.t("public_recipe_pages.show.unknown")}/
  end

  test "stale snapshot ignores scalar public ingredients" do
    share = create_share(enabled: true)
    share.update!(snapshot: {
      "title" => "Scalar ingredients recipe",
      "recipe" => {
        "targets" => {},
        "source_brew" => {},
        "ingredients" => [ nil, "matcha", 200, { "name" => "salt" } ]
      }
    })

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-recipe-finish]", text: /salt/
    assert_select "[data-testid=public-recipe-finish]", text: /matcha/, count: 0
  end

  test "public recipe request path and redirects redact bearer tokens for logs" do
    share = create_share(enabled: true, password: "espresso")
    media_handle = "opaque-media-handle"

    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/r/#{share.token}/media/#{media_handle}?token=secret")
    )
    request.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    assert_equal "/r/[FILTERED]/media/[FILTERED]?token=[FILTERED]", request.filtered_path
    assert_equal "[FILTERED]", request.parameter_filter.filter(media_id: media_handle).fetch(:media_id)

    post unlock_public_recipe_page_path(share.token), params: { password: "espresso" }

    assert_redirected_to public_recipe_page_path(share.token)
    assert_equal "[FILTERED]", response.filtered_location
  end

  private
    def create_share(enabled:, password: nil)
      recipe = recipes(:household_recipe)
      recipe.record_links.destroy_all
      recipe.record_links.create!(
        label: "Recipe writeup",
        url: "https://example.test/recipe",
        kind: "info",
        visibility: "public"
      )
      recipe.record_links.create!(
        label: "Private recipe link",
        url: "https://example.test/private-recipe",
        kind: "info",
        visibility: "private"
      )
      profile = recipe.profile.deep_dup
      profile["source_brew"] ||= {}
      profile["source_brew"]["public_note"] = "Public source note."
      recipe.update!(profile:)
      snapshot = PublicRecipeShareSnapshotBuilder.new(recipe:, title: "Shared recipe").call

      recipe.create_public_recipe_share!(
        workspace: recipe.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared recipe",
        enabled:,
        password:,
        snapshot:
      )
    end
end
