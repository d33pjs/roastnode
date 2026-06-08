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

  test "show renders finish ingredients and finish note" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" },
      { "amount" => "1", "unit" => "shot", "name" => "honey" }
    ]
    profile["finish_note"] = "Add matcha after pulling the espresso."
    recipe.update!(profile:)

    get recipe_path(recipe)

    assert_response :success
    assert_select "[data-testid=recipe-finish-card]", text: /200 ml matcha/
    assert_select "[data-testid=recipe-finish-card]", text: /1 shot honey/
    assert_select "[data-testid=recipe-finish-card]", text: /Add matcha/
  end

  test "show renders finished drink photo through private media route" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    attachment = recipe.photos.attachments.first

    get recipe_path(recipe)

    assert_response :success
    assert_select "img[data-testid=recipe-finished-photo][src=?]", media_attachment_path(attachment, variant: :thumbnail)
  end

  test "writer exports recipe as portable json attachment" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)

    get export_recipe_path(recipe)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match recipe.export_filename, response.headers["Content-Disposition"]
    payload = JSON.parse(response.body)
    assert_equal "roastnode.recipe", payload.fetch("schema")
    assert_equal recipe.title, payload.fetch("recipe").fetch("title")
  end

  test "writer imports recipe upload as unlinked snapshot" do
    sign_in_as(users(:one))
    workspace = workspaces(:household)

    assert_difference -> { workspace.recipes.count }, 1 do
      assert_no_difference -> { workspace.beans.count } do
        assert_no_difference -> { workspace.equipment.count } do
          assert_no_difference -> { workspace.preparation_tools.count } do
            assert_no_difference -> { workspace.brews.count } do
              post import_recipes_path, params: {
                recipe_import: {
                  file: fixture_file_upload("recipe_export.json", "application/json")
                }
              }
            end
          end
        end
      end
    end

    recipe = workspace.recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert_nil recipe.source_brew
    assert_equal "Uploaded recipe", recipe.title
    assert_equal "18.8", recipe.profile.dig("targets", "dose_grams")
  end

  test "writer import rejects malformed json" do
    sign_in_as(users(:one))

    assert_no_difference -> { workspaces(:household).recipes.count } do
      post import_recipes_path, params: {
        recipe_import: {
          file: fixture_file_upload("bad_recipe_export.json", "application/json")
        }
      }
    end

    assert_redirected_to recipes_path
  end

  test "writer opens new recipe form from brew" do
    sign_in_as(users(:one))

    get new_recipe_path(source_brew_id: brews(:morning_espresso).id)

    assert_response :success
    assert_select "input[name=?][value=?]", "recipe[title]", "Espresso with Good Coffee - House Blend"
    assert_select "input[name=?][value=?]", "recipe[targets][dose_grams]", "18.0"
    assert_select "input[name=?][value=?]", "recipe[targets][grind_setting]", "12"
  end

  test "writer cannot open new recipe form from quick drip brew" do
    sign_in_as(users(:one))
    source_brew = create_quick_drip_source_brew

    get new_recipe_path(source_brew_id: source_brew.id)

    assert_response :not_found
  end

  test "new recipe form suggests source brew primary photo without selecting it" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    brew.set_primary_photo!(brew.photos.attachments.first)

    get new_recipe_path(source_brew_id: brew.id)

    assert_response :success
    assert_select "[data-testid=source-brew-photo-suggestion]"
    assert_select "input[type=checkbox][name=?][checked]", "recipe[use_source_brew_photo]", count: 0
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

  test "writer cannot create recipe from quick drip brew" do
    sign_in_as(users(:one))
    source_brew = create_quick_drip_source_brew

    assert_no_difference -> { workspaces(:household).recipes.count } do
      post recipes_path, params: {
        recipe: {
          source_brew_id: source_brew.id,
          title: "Quick Drip recipe"
        }
      }
    end

    assert_response :not_found
  end

  test "writer can reuse source brew primary photo for recipe" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    brew.set_primary_photo!(brew.photos.attachments.first)

    post recipes_path, params: {
      recipe: {
        source_brew_id: brew.id,
        title: "Photo recipe",
        use_source_brew_photo: "1"
      }
    }

    recipe = workspaces(:household).recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert recipe.photos.attached?
    assert_equal brew.primary_photo_attachment.blob_id, recipe.primary_photo_attachment.blob_id
  end

  test "writer create keeps one finished drink photo when upload and source reuse are both present" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "source-photo.jpg",
      content_type: "image/jpeg"
    )
    brew.set_primary_photo!(brew.photos.attachments.first)

    post recipes_path, params: {
      recipe: {
        source_brew_id: brew.id,
        title: "Single photo recipe",
        use_source_brew_photo: "1",
        source_brew_photo_attachment_id: brew.primary_photo_attachment.id,
        photos: [
          fixture_file_upload("photo.jpg", "image/jpeg")
        ]
      }
    }

    recipe = workspaces(:household).recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert_equal 1, recipe.photos.attachments.count
    assert_not_equal brew.primary_photo_attachment.blob_id, recipe.primary_photo_attachment.blob_id
  end

  test "writer cannot reuse cross workspace source photo" do
    sign_in_as(users(:one))
    other_brew = brews(:other_workspace_brew)
    other_brew.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    other_brew.set_primary_photo!(other_brew.photos.attachments.first)

    assert_no_difference -> { workspaces(:household).recipes.count } do
      post recipes_path, params: {
        recipe: {
          source_brew_id: brews(:morning_espresso).id,
          source_brew_photo_attachment_id: other_brew.primary_photo_attachment.id,
          use_source_brew_photo: "1"
        }
      }
    end

    assert_response :not_found
  end

  test "writer uploads recipe finished drink photo" do
    sign_in_as(users(:one))

    post recipes_path, params: {
      recipe: {
        source_brew_id: brews(:morning_espresso).id,
        title: "Uploaded photo recipe",
        photos: [
          fixture_file_upload("photo.jpg", "image/jpeg")
        ]
      }
    }

    recipe = workspaces(:household).recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert recipe.primary_photo_attachment.present?
  end

  test "writer creates recipe with structured ingredients and finish note" do
    sign_in_as(users(:one))

    assert_difference -> { workspaces(:household).recipes.count }, 1 do
      post recipes_path, params: {
        recipe: {
          source_brew_id: brews(:morning_espresso).id,
          title: "Matcha honey espresso",
          finish_note: "Add matcha after pulling the espresso, then stir in honey.",
          ingredients: {
            "0" => { amount: "200", unit: "ml", name: "matcha" },
            "1" => { amount: "1", unit: "shot", name: "honey" },
            "2" => { amount: "", unit: "", name: "" }
          }
        }
      }
    end

    recipe = workspaces(:household).recipes.order(:created_at).last
    assert_redirected_to recipe_path(recipe)
    assert_equal "Add matcha after pulling the espresso, then stir in honey.", recipe.profile["finish_note"]
    assert_equal [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" },
      { "amount" => "1", "unit" => "shot", "name" => "honey" }
    ], recipe.profile["ingredients"]
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

  test "writer uploading new finished drink photo on edit makes it primary and rendered" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "old-photo.jpg",
      content_type: "image/jpeg"
    )
    old_attachment = recipe.primary_photo_attachment

    patch recipe_path(recipe), params: {
      recipe: {
        title: recipe.title,
        photos: [
          fixture_file_upload("photo.jpg", "image/jpeg")
        ]
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    new_attachment = recipe.photos.attachments.order(:id).last
    assert_not_equal old_attachment.id, new_attachment.id
    assert_equal 1, recipe.photos.attachments.count
    assert_not_includes recipe.photos.attachments.map(&:id), old_attachment.id
    assert_equal new_attachment, recipe.primary_photo_attachment

    get recipe_path(recipe)

    assert_response :success
    assert_select "img[data-testid=recipe-finished-photo][src=?]", media_attachment_path(new_attachment, variant: :thumbnail)
    assert_select "img[data-testid=recipe-finished-photo][src=?]", media_attachment_path(old_attachment, variant: :thumbnail), count: 0
  end

  test "invalid recipe update with uploaded finished drink photo does not attach it" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "old-photo.jpg",
      content_type: "image/jpeg"
    )
    old_attachment = recipe.primary_photo_attachment
    existing_photo_count = recipe.photos.attachments.count

    patch recipe_path(recipe), params: {
      recipe: {
        title: "x" * 161,
        photos: [
          fixture_file_upload("photo.jpg", "image/jpeg")
        ]
      }
    }

    assert_response :unprocessable_entity
    recipe.reload
    assert_equal existing_photo_count, recipe.photos.attachments.count
    assert_equal old_attachment, recipe.primary_photo_attachment
  end

  test "writer edits and removes structured ingredients" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" },
      { "amount" => "1", "unit" => "shot", "name" => "honey" }
    ]
    profile["finish_note"] = "Old finish."
    recipe.update!(profile:)

    patch recipe_path(recipe), params: {
      recipe: {
        title: recipe.title,
        finish_note: "Stir gently.",
        ingredients: {
          "0" => { amount: "180", unit: "ml", name: "iced matcha" },
          "1" => { amount: "", unit: "", name: "" }
        }
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal "Stir gently.", recipe.profile["finish_note"]
    assert_equal [
      { "amount" => "180", "unit" => "ml", "name" => "iced matcha" }
    ], recipe.profile["ingredients"]
  end

  test "writer edits structured ingredients with array params" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)

    patch recipe_path(recipe), params: {
      recipe: {
        title: recipe.title,
        ingredients: [
          { amount: "200", unit: "ml", name: "matcha" },
          { amount: "", unit: "", name: "" },
          { amount: "1", unit: "shot", name: "honey" }
        ]
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" },
      { "amount" => "1", "unit" => "shot", "name" => "honey" }
    ], recipe.profile["ingredients"]
  end

  test "writer clears structured ingredients with empty array params" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" }
    ]
    recipe.update!(profile:)

    patch recipe_path(recipe), params: {
      recipe: {
        title: recipe.title,
        ingredients: []
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal [], recipe.profile["ingredients"]
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

    get export_recipe_path(recipe)
    assert_redirected_to root_path

    post import_recipes_path, params: {
      recipe_import: {
        file: fixture_file_upload("recipe_export.json", "application/json")
      }
    }
    assert_redirected_to root_path

    delete recipe_path(recipe)
    assert_redirected_to root_path
  end

  test "cross workspace recipe is not found" do
    sign_in_as(users(:one))

    get recipe_path(recipes(:other_workspace_recipe))

    assert_response :not_found
  end

  private
    def create_quick_drip_source_brew
      workspaces(:household).brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        brewer: equipment(:household_brewer),
        method: "quick_drip",
        occurred_at: Time.current,
        machine_cups: 6,
        coffee_spoons: 5,
        beverage_grams: 900,
        total_time_seconds: 320,
        taste_balance: "neutral"
      )
    end
end
