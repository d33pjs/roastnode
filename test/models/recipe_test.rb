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
end
