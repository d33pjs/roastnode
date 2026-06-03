require "test_helper"

class RecipeExporterTest < ActiveSupport::TestCase
  test "exports portable recipe json without private notes or private links" do
    recipe = recipes(:household_recipe)
    recipe.record_links.create!(
      workspace: recipe.workspace,
      label: "Public guide",
      url: "https://example.com/guide",
      kind: "info",
      visibility: "public",
      position: 10
    )
    recipe.record_links.create!(
      workspace: recipe.workspace,
      label: "Private vendor",
      url: "https://example.com/private",
      kind: "buy",
      visibility: "private",
      position: 20
    )

    payload = RecipeExporter.new(recipe).call

    assert_equal "roastnode.recipe", payload.fetch("schema")
    assert_equal 1, payload.fetch("version")
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, payload.fetch("generated_at"))
    exported_recipe = payload.fetch("recipe")
    assert_equal recipe.title, exported_recipe.fetch("title")
    assert_equal "espresso", exported_recipe.fetch("method")
    assert_equal "18.0", exported_recipe.fetch("profile").fetch("targets").fetch("dose_grams")
    assert_equal [ "Public guide" ], exported_recipe.fetch("links").map { |link| link.fetch("label") }

    json = JSON.generate(payload)
    assert_not_includes json, brews(:morning_espresso).notes
    assert_not_includes json, "Private vendor"
    assert_not_includes json, "one@example.com"
  end

  test "exports ingredients and finish note but no media internals" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" }
    ]
    profile["finish_note"] = "Pour espresso over matcha."
    recipe.update!(profile:)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )

    payload = RecipeExporter.new(recipe).call

    exported_profile = payload.fetch("recipe").fetch("profile")
    assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], exported_profile.fetch("ingredients")
    assert_equal "Pour espresso over matcha.", exported_profile.fetch("finish_note")
    json = JSON.generate(payload)
    assert_not_includes json, "attachment_id"
    assert_not_includes json, "/rails/active_storage"
    assert_not_includes json, "photo.jpg"
  end
end
