require "test_helper"

class PublicRecipeShareSnapshotBuilderTest < ActiveSupport::TestCase
  test "does not copy direct bean websites from recipe profiles" do
    recipe = recipes(:household_recipe)
    recipe.update!(
      profile: recipe.profile.deep_merge(
        "bean" => {
          "name" => "Safe bean name",
          "purchase_url" => "https://private-purchase.example/recipe-secret",
          "coffee_origin_url" => "https://private-origin.example/recipe-secret",
          "links" => [
            {
              "label" => "Public roaster page",
              "url" => "https://public-record-link.example/coffee",
              "kind" => "info",
              "visibility" => "public"
            }
          ]
        }
      )
    )

    snapshot = PublicRecipeShareSnapshotBuilder.new(
      recipe:,
      title: "Shared recipe",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "Safe bean name", snapshot.dig("bean", "name")
    assert_equal "https://public-record-link.example/coffee", snapshot.dig("bean", "links", 0, "url")
    assert_not snapshot.fetch("bean").key?("purchase_url")
    assert_not snapshot.fetch("bean").key?("coffee_origin_url")
    assert_not_includes snapshot.to_json, "private-purchase.example"
    assert_not_includes snapshot.to_json, "private-origin.example"
  end

  test "does not copy serving metadata from recipe profiles into public snapshots" do
    recipe = recipes(:household_recipe)
    recipe.update!(
      profile: recipe.profile.deep_merge(
        "source_brew" => {
          "served_for_guest" => true,
          "guest_name" => "Anna",
          "cup_style" => "Latte",
          "recipient_kind" => "household_member",
          "recipient_user_id" => 987_654,
          "recipient_user_display_name" => "Private Recipient Label",
          "recipient_user_email_address" => "private-recipient@example.com",
          "recipient_name" => "Private Guest Name",
          "recipient_user" => {
            "display_name" => "Nested Private Recipient",
            "email_address" => "nested-private@example.com"
          }
        }
      )
    )

    snapshot = PublicRecipeShareSnapshotBuilder.new(
      recipe:,
      title: "Shared recipe",
      selected_photo_attachment_ids: []
    ).call

    assert_not_includes snapshot.to_json, "Anna"
    assert_not_includes snapshot.to_json, "Latte"
    assert_not_includes snapshot.to_json, "served_for_guest"
    assert_not_includes snapshot.to_json, "guest_name"
    assert_not_includes snapshot.to_json, "cup_style"
    %w[
      recipient_kind recipient_user_id recipient_user_display_name recipient_user_email_address recipient_name recipient_user
      Private Recipient Label private-recipient@example.com Private Guest Name Nested Private Recipient nested-private@example.com
    ].each do |value|
      assert_not_includes snapshot.to_json, value
    end
  end
end
