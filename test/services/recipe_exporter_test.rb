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

  test "scrubs media internals from polluted profile and source snapshot" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["bean"] = {
      "display_name" => "Safe bean",
      "photo_attachment_id" => 123,
      "photo" => {
        "filename" => "private-bean.jpg",
        "url" => "/rails/active_storage/blobs/private-bean.jpg"
      },
      "links" => [
        { "label" => "Bean notes", "url" => "https://example.test/bean" }
      ],
      "selected_photo_attachment_ids" => [ 123 ]
    }
    profile["guide"] ||= {}
    profile["guide"]["note"] = "Keep the crema glossy."
    profile["guide"]["attachment_id"] = 456
    source_snapshot = recipe.source_snapshot.deep_dup
    source_snapshot["source_brew"] ||= {}
    source_snapshot["source_brew"]["public_note"] = "Public source note."
    source_snapshot["source_brew"]["photos"] = [
      {
        "attachment_id" => 789,
        "filename" => "private-brew.jpg",
        "url" => "/media_attachments/789"
      }
    ]
    source_snapshot["source_brew"]["links"] = [
      { "label" => "Source notes", "url" => "https://example.test/source" }
    ]
    source_snapshot["equipment"] = {
      "grinder" => {
        "name" => "Safe grinder",
        "blob_id" => 987,
        "signed_id" => "signed-private-media",
        "media_url" => "/rails/active_storage/representations/private-grinder.jpg"
      }
    }
    recipe.update!(profile:, source_snapshot:)

    payload = RecipeExporter.new(recipe).call

    exported_recipe = payload.fetch("recipe")
    assert_equal "Safe bean", exported_recipe.dig("profile", "bean", "display_name")
    assert_equal "Keep the crema glossy.", exported_recipe.dig("profile", "guide", "note")
    assert_equal "https://example.test/bean", exported_recipe.dig("profile", "bean", "links", 0, "url")
    assert_equal "Public source note.", exported_recipe.dig("source_snapshot", "source_brew", "public_note")
    assert_equal "https://example.test/source", exported_recipe.dig("source_snapshot", "source_brew", "links", 0, "url")
    assert_equal "Safe grinder", exported_recipe.dig("source_snapshot", "equipment", "grinder", "name")

    json = JSON.generate(payload)
    assert_not_includes json, "attachment_id"
    assert_not_includes json, "selected_photo_attachment_ids"
    assert_not_includes json, "blob_id"
    assert_not_includes json, "signed_id"
    assert_not_includes json, "filename"
    assert_not_includes json, "private-bean.jpg"
    assert_not_includes json, "private-brew.jpg"
    assert_not_includes json, "/rails/active_storage"
    assert_not_includes json, "/media_attachments"
  end
end
