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
