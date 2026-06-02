require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace recipes only and navigation includes recipes" do
    sign_in_as(users(:one))

    get recipes_path

    assert_response :success
    assert_select "a[data-testid=app-nav-recipes][href=?]", recipes_path
    assert_select "h1", I18n.t("recipes.index.title")
    assert_select "a[href=?]", recipe_path(recipes(:household_recipe)), text: /House Blend reference/
    assert_select "body", text: recipes(:other_workspace_recipe).title, count: 0
  end

  test "show renders recipe targets and local source brew link" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)

    get recipe_path(recipe)

    assert_response :success
    assert_select "h1", recipe.title
    assert_select "[data-testid=recipe-target-guide]", text: /Set grinder/
    assert_select "[data-testid=recipe-target-guide]", text: /12/
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /Source brew/
    assert_select "body", text: recipes(:other_workspace_recipe).title, count: 0
  end

  test "writer opens new recipe form from brew" do
    sign_in_as(users(:one))

    get new_recipe_path(source_brew_id: brews(:morning_espresso).id)

    assert_response :success
    assert_select "input[name=?][value=?]", "recipe[title]", "Espresso with Good Coffee - House Blend"
    assert_select "input[name=?][value=?]", "recipe[targets][dose_grams]", "18.0"
    assert_select "input[name=?][value=?]", "recipe[targets][grind_setting]", "12"
  end

  test "writer creates recipe from brew with edited exact target values" do
    sign_in_as(users(:one))

    assert_difference -> { workspaces(:household).recipes.count }, 1 do
      post recipes_path, params: {
        recipe: {
          source_brew_id: brews(:morning_espresso).id,
          title: "Dialed in House Blend",
          guide_note: "Stop as soon as blonding starts.",
          pressure_note: "Full pressure, stable gauge.",
          targets: {
            dose_grams: "18.5",
            beverage_grams: "44.0",
            grind_setting: "12.5",
            total_time_seconds: "30"
          }
        }
      }
    end

    recipe = workspaces(:household).recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert_equal "Dialed in House Blend", recipe.title
    assert_equal "18.5", recipe.profile.dig("targets", "dose_grams")
    assert_equal "44.0", recipe.profile.dig("targets", "beverage_grams")
    assert_equal "12.5", recipe.profile.dig("targets", "grind_setting")
    assert_equal 30, recipe.profile.dig("targets", "total_time_seconds")
    assert_equal "Stop as soon as blonding starts.", recipe.profile.dig("guide", "note")
    assert_equal "Full pressure, stable gauge.", recipe.profile.dig("guide", "pressure_note")
  end

  test "writer edits exact target values" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)

    patch recipe_path(recipe), params: {
      recipe: {
        title: "Edited target",
        guide_note: "Aim for syrupy flow.",
        targets: {
          dose_grams: "18.2",
          beverage_grams: "42.0",
          grind_setting: "11.75",
          total_time_seconds: "29"
        }
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal "Edited target", recipe.title
    assert_equal "18.2", recipe.profile.dig("targets", "dose_grams")
    assert_equal "42.0", recipe.profile.dig("targets", "beverage_grams")
    assert_equal "11.75", recipe.profile.dig("targets", "grind_setting")
    assert_equal 29, recipe.profile.dig("targets", "total_time_seconds")
    assert_equal "Aim for syrupy flow.", recipe.profile.dig("guide", "note")
  end

  test "viewer can read recipes but cannot create edit destroy or log" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    recipe = recipes(:household_recipe)

    get recipes_path
    assert_response :success

    get recipe_path(recipe)
    assert_response :success
    assert_select "a[href=?]", edit_recipe_path(recipe), count: 0
    assert_select "a[href=?]", log_recipe_path(recipe), count: 0

    get new_recipe_path(source_brew_id: brews(:morning_espresso).id)
    assert_redirected_to root_path

    post recipes_path, params: { recipe: { source_brew_id: brews(:morning_espresso).id, title: "Nope" } }
    assert_redirected_to root_path

    get edit_recipe_path(recipe)
    assert_redirected_to root_path

    patch recipe_path(recipe), params: { recipe: { title: "Nope" } }
    assert_redirected_to root_path

    get log_recipe_path(recipe)
    assert_redirected_to root_path

    delete recipe_path(recipe)
    assert_redirected_to root_path
  end

  test "cross workspace recipe is not found" do
    sign_in_as(users(:one))

    get recipe_path(recipes(:other_workspace_recipe))

    assert_response :not_found
  end
end
