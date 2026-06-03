require "test_helper"

class PublicRecipePagesControllerTest < ActionDispatch::IntegrationTest
  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_recipe_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without authentication" do
    share = create_share(enabled: true)

    get public_recipe_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-recipe-page]"
    assert_select "[data-testid=public-recipe-target-guide]", text: /Set grinder/
    assert_select "body", text: /Shared recipe/
    assert_select "body", text: /Public source note/
    assert_select "a[href='https://example.test/recipe'][data-testid=public-recipe-link]", text: "Recipe writeup"
    assert_select "body", text: /Private recipe link/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
    assert_no_match "attachment_id", response.body
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
