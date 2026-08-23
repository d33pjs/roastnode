require "test_helper"

class RecipeSnapshotBuilderTest < ActiveSupport::TestCase
  test "builds public-safe target profile from a brew" do
    brew = brews(:morning_espresso)
    users(:two).update!(display_name: "Private Household Recipient")
    brew.update!(
      public_note: "Sweet, repeatable shot.",
      recipient_kind: "household_member",
      recipient_user: users(:two),
      cup_style: "Private Household Cup"
    )
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
    assert_no_match "Private Household Recipient", snapshot.inspect
    assert_no_match users(:two).email_address, snapshot.inspect
    assert_no_match "Private Household Cup", snapshot.inspect
    assert_no_match "recipient_kind", snapshot.inspect
    assert_no_match "recipient_user_id", snapshot.inspect
    assert_no_match "recipient_user", snapshot.inspect
    assert_no_match "recipient_user_display_name", snapshot.inspect
    assert_no_match "recipient_user_email_address", snapshot.inspect
    assert_no_match "recipient_name", snapshot.inspect
    assert_no_match "served_for_guest", snapshot.inspect
    assert_no_match "guest_name", snapshot.inspect
    assert_no_match "cup_style", snapshot.inspect
  end

  test "does not copy a named guest or private cup into recipe source snapshots" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Private Guest Sentinel", cup_style: "Private Guest Cup")

    snapshot = RecipeSnapshotBuilder.new(brew:, title: "Private boundary").call

    assert_no_match(/Private Guest Sentinel|Private Guest Cup/, snapshot.to_json)
    %w[
      recipient_kind recipient_user_id recipient_user recipient_user_display_name recipient_user_email_address
      recipient_name cup_style served_for_guest guest_name
    ].each do |key|
      assert_not_includes snapshot.to_json, key
    end
  end
end
