require "test_helper"

class RecipeSnapshotBuilderTest < ActiveSupport::TestCase
  test "builds public-safe target profile from a brew" do
    brew = brews(:morning_espresso)
    brew.update!(public_note: "Sweet, repeatable shot.")
    brew.bean.update!(public_note: "Works well for milk drinks.")
    brew.record_links.create!(
      workspace: brew.workspace,
      label: "Shot notes",
      url: "https://example.com/shot",
      kind: "info",
      visibility: "public",
      position: 10
    )
    brew.record_links.create!(
      workspace: brew.workspace,
      label: "Private notes",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private",
      position: 20
    )

    snapshot = RecipeSnapshotBuilder.new(
      brew:,
      title: "House Blend reference",
      guide_note: "Watch for a steady first drip."
    ).call

    assert_equal "House Blend reference", snapshot["title"]
    assert_equal "espresso", snapshot["method"]
    assert_equal "18.0", snapshot.dig("targets", "dose_grams")
    assert_equal "40.0", snapshot.dig("targets", "beverage_grams")
    assert_equal "12", snapshot.dig("targets", "grind_setting")
    assert_equal 28, snapshot.dig("targets", "total_time_seconds")
    assert_equal "Watch for a steady first drip.", snapshot.dig("guide", "note")
    assert_equal "House Blend", snapshot.dig("bean", "name")
    assert_equal "Good Coffee", snapshot.dig("bean", "roaster_name")
    assert_equal "Niche Zero", snapshot.dig("equipment", "grinder", "name")
    assert_equal "Bianca", snapshot.dig("equipment", "machine", "name")
    assert_equal [ "WDT" ], snapshot.fetch("tools").map { |tool| tool["name"] }
    assert_equal "Sweet, repeatable shot.", snapshot.dig("source_brew", "public_note")
    assert_equal 4, snapshot.dig("source_brew", "rating")
    assert_equal [ "Shot notes" ], snapshot.dig("source_brew", "links").map { |link| link["label"] }
    assert_no_match "Balanced morning shot.", snapshot.inspect
    assert_no_match "Private notes", snapshot.inspect
  end
end
