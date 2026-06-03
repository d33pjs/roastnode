require "test_helper"

class RecipeImporterTest < ActiveSupport::TestCase
  test "imports recipe snapshot without creating coffee records" do
    payload = export_payload(
      "links" => [
        { "label" => "Shared guide", "url" => "https://example.com/guide", "kind" => "info", "position" => 10 }
      ]
    )
    workspace = workspaces(:household)

    assert_no_difference -> { workspace.beans.count } do
      assert_no_difference -> { workspace.equipment.count } do
        assert_no_difference -> { workspace.preparation_tools.count } do
          assert_no_difference -> { workspace.brews.count } do
            @recipe = RecipeImporter.new(workspace:, user: users(:one), json: JSON.generate(payload)).call
          end
        end
      end
    end

    assert_equal workspace, @recipe.workspace
    assert_nil @recipe.source_brew
    assert_equal "Imported House Blend", @recipe.title
    assert_equal "19.0", @recipe.profile.fetch("targets").fetch("dose_grams")
    assert_equal [ "Shared guide" ], @recipe.record_links.ordered.pluck(:label)
  end

  test "imports ingredients and finish note without media" do
    payload = export_payload(
      "profile" => export_payload.fetch("recipe").fetch("profile").merge(
        "ingredients" => [
          { "amount" => "200", "unit" => "ml", "name" => "matcha" },
          { "amount" => "", "unit" => "", "name" => "" }
        ],
        "finish_note" => "Stir in honey."
      )
    )

    recipe = RecipeImporter.new(workspace: workspaces(:household), user: users(:one), json: JSON.generate(payload)).call

    assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], recipe.profile["ingredients"]
    assert_equal "Stir in honey.", recipe.profile["finish_note"]
    assert_not recipe.photos.attached?
  end

  test "scrubs media internals from imported profile and source snapshot" do
    base_payload = export_payload
    payload = export_payload(
      "profile" => base_payload.fetch("recipe").fetch("profile").merge(
        "bean" => {
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
        },
        "guide" => base_payload.fetch("recipe").fetch("profile").fetch("guide").merge(
          "attachment_id" => 456
        )
      ),
      "source_snapshot" => base_payload.fetch("recipe").fetch("source_snapshot").merge(
        "source_brew" => {
          "occurred_at" => "2026-06-01T08:00:00Z",
          "photos" => [
            {
              "attachment_id" => 789,
              "filename" => "private-brew.jpg",
              "url" => "/media_attachments/789"
            }
          ],
          "links" => [
            { "label" => "Source notes", "url" => "https://example.test/source" }
          ]
        },
        "equipment" => {
          "grinder" => {
            "name" => "Safe grinder",
            "blob_id" => 987,
            "signed_id" => "signed-private-media",
            "media_url" => "/rails/active_storage/representations/private-grinder.jpg"
          }
        }
      )
    )

    recipe = RecipeImporter.new(workspace: workspaces(:household), user: users(:one), json: JSON.generate(payload)).call

    assert_equal "Safe bean", recipe.profile.dig("bean", "display_name")
    assert_equal "https://example.test/bean", recipe.profile.dig("bean", "links", 0, "url")
    assert_equal "Safe grinder", recipe.source_snapshot.dig("equipment", "grinder", "name")
    assert_equal "https://example.test/source", recipe.source_snapshot.dig("source_brew", "links", 0, "url")

    json = JSON.generate("profile" => recipe.profile, "source_snapshot" => recipe.source_snapshot)
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

  test "rejects malformed json" do
    error = assert_raises(RecipeImporter::ImportError) do
      RecipeImporter.new(workspace: workspaces(:household), user: users(:one), json: "{").call
    end

    assert_match(/Invalid JSON/, error.message)
  end

  test "rejects unsafe link schemes" do
    payload = export_payload(
      "links" => [
        { "label" => "Bad link", "url" => "javascript:alert(1)", "kind" => "info", "position" => 10 }
      ]
    )

    error = assert_raises(RecipeImporter::ImportError) do
      RecipeImporter.new(workspace: workspaces(:household), user: users(:one), json: JSON.generate(payload)).call
    end

    assert_match(/HTTP or HTTPS/, error.message)
  end

  private
    def export_payload(recipe_overrides = {})
      {
        "schema" => "roastnode.recipe",
        "version" => 1,
        "generated_at" => "2026-06-02T12:00:00Z",
        "recipe" => {
          "title" => "Imported House Blend",
          "method" => "espresso",
          "profile" => {
            "title" => "Imported House Blend",
            "method" => "espresso",
            "targets" => {
              "dose_grams" => "19.0",
              "beverage_grams" => "45.0",
              "grind_setting" => "11.5",
              "total_time_seconds" => 32
            },
            "guide" => {
              "note" => "Stop before blonding."
            },
            "source_brew" => {
              "occurred_at" => "2026-06-01T08:00:00Z",
              "rating" => 5
            }
          },
          "source_snapshot" => {
            "source_brew" => {
              "occurred_at" => "2026-06-01T08:00:00Z"
            }
          },
          "links" => []
        }.merge(recipe_overrides)
      }
    end
end
