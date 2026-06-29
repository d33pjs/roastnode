require "test_helper"

class PublicRecipeShareSnapshotBuilderTest < ActiveSupport::TestCase
  test "does not copy serving metadata from recipe profiles into public snapshots" do
    recipe = recipes(:household_recipe)
    recipe.update!(
      profile: recipe.profile.deep_merge(
        "source_brew" => {
          "served_for_guest" => true,
          "guest_name" => "Anna",
          "cup_style" => "Latte"
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
  end
end
