require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "is valid for a workspace source brew profile" do
    recipe = Recipe.new(
      workspace: workspaces(:household),
      created_by: users(:one),
      source_brew: brews(:morning_espresso),
      title: "Good morning espresso",
      method: "espresso",
      profile: RecipeSnapshotBuilder.new(brew: brews(:morning_espresso), title: "Good morning espresso").call,
      source_snapshot: { "brew" => { "id" => brews(:morning_espresso).id } }
    )

    assert recipe.valid?
  end

  test "requires source brew to belong to recipe workspace" do
    recipe = Recipe.new(
      workspace: workspaces(:household),
      created_by: users(:one),
      source_brew: brews(:other_workspace_brew),
      title: "Wrong workspace",
      method: "espresso",
      profile: {},
      source_snapshot: {}
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:source_brew], "must belong to the workspace"
  end

  test "requires creator to belong to recipe workspace" do
    recipe = Recipe.new(
      workspace: workspaces(:other_household),
      created_by: users(:one),
      source_brew: nil,
      title: "Imported profile",
      method: "espresso",
      profile: { "method" => "espresso", "targets" => {} },
      source_snapshot: {}
    )

    assert_not recipe.valid?
    assert_includes recipe.errors[:created_by], "must belong to the workspace"
  end

  test "export filename is stable and json extension" do
    recipe = recipes(:household_recipe)

    assert_match(/\Ahouse-blend-reference-[a-z0-9]+\.json\z/, recipe.export_filename)
  end

  test "recipe supports one primary finished drink photo" do
    recipe = recipes(:household_recipe)
    recipe.photos.attach(
      io: file_fixture("photo.jpg").open,
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )

    assert recipe.photos.attached?
    assert_equal recipe.photos.attachments.first, recipe.primary_photo_attachment
  end

  test "source brew can be deleted while recipe keeps its profile" do
    recipe = recipes(:household_recipe)
    source_brew = recipe.source_brew

    source_brew.destroy_with_inventory_reversal!

    assert_nil recipe.reload.source_brew_id
    assert_equal "12", recipe.profile.dig("targets", "grind_setting")
  end
end
