require "test_helper"

class PublicRecipeShareTest < ActiveSupport::TestCase
  test "generates token and starts disabled" do
    share = PublicRecipeShare.create!(
      workspace: workspaces(:household),
      recipe: recipes(:household_recipe),
      created_by: users(:one),
      updated_by: users(:one),
      title: "House recipe"
    )

    assert share.token.present?
    assert_equal Digest::SHA256.hexdigest(share.token), share.token_digest
    assert_not share.enabled?
    assert_equal({}, share.snapshot)
  end

  test "finds enabled shares by token digest" do
    share = PublicRecipeShare.create!(
      workspace: workspaces(:household),
      recipe: recipes(:household_recipe),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_equal share, PublicRecipeShare.find_enabled_by_token!(share.token)
    assert_raises(ActiveRecord::RecordNotFound) { PublicRecipeShare.find_enabled_by_token!("wrong") }
  end

  test "optional password protection works" do
    share = PublicRecipeShare.create!(
      workspace: workspaces(:household),
      recipe: recipes(:household_recipe),
      created_by: users(:one),
      updated_by: users(:one),
      password: "espresso"
    )

    assert share.password_protected?
    assert share.authenticate_password("espresso")
    assert_not share.authenticate_password("wrong")
  end

  test "only one public share can exist for a recipe" do
    recipe = recipes(:household_recipe)
    PublicRecipeShare.create!(
      workspace: recipe.workspace,
      recipe:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    duplicate = PublicRecipeShare.new(
      workspace: recipe.workspace,
      recipe:,
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:recipe_id], "has already been taken"
  end

  test "writer can manage own recipe share but not another writers recipe share" do
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicRecipeShare.create!(
      workspace: workspaces(:household),
      recipe: recipes(:household_recipe),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:one))
    assert_not share.manageable_by?(users(:two))
  end

  test "workspace admin can manage any workspace recipe share" do
    memberships(:member).update!(role: "admin")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicRecipeShare.create!(
      workspace: workspaces(:household),
      recipe: recipes(:household_recipe),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:two))
  end

  test "snapshot excludes private notes media ids email and costs" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["private_note"] = "Secret recipe note"
    profile["bean"] = {
      "display_name" => "Public bean",
      "notes" => "Private bean note",
      "photo_attachment_id" => 123,
      "purchase_price_cents" => 9999,
      "links" => []
    }
    profile["equipment"] = {
      "grinder" => {
        "name" => "Public grinder",
        "purchase_price_cents" => 12345,
        "attachment_id" => 456
      }
    }
    recipe.update!(profile:)
    share = PublicRecipeShare.create!(
      workspace: recipe.workspace,
      recipe:,
      created_by: users(:one),
      updated_by: users(:one)
    )

    share.refresh_snapshot!(title: "Public recipe", updated_by: users(:one))

    json = JSON.generate(share.snapshot)
    assert_includes json, "Public recipe"
    assert_includes json, "Public bean"
    assert_not_includes json, "Secret recipe note"
    assert_not_includes json, "Private bean note"
    assert_not_includes json, "purchase_price"
    assert_not_includes json, "attachment_id"
    assert_not_includes json, "one@example.com"
  end

  test "snapshot includes public ingredients and finish note" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" }
    ]
    profile["finish_note"] = "Pour espresso over matcha."
    recipe.update!(profile:)

    share = PublicRecipeShare.create!(
      workspace: recipe.workspace,
      recipe:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    share.refresh_snapshot!(title: "Public recipe", selected_photo_attachment_ids: [], updated_by: users(:one))

    assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], share.snapshot.dig("recipe", "ingredients")
    assert_equal "Pour espresso over matcha.", share.snapshot.dig("recipe", "finish_note")
  end

  test "snapshot sanitizes public ingredients and finish note" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "  #{"2" * 40}  ", "unit" => "  #{"m" * 40}  ", "name" => "  #{"matcha" * 30}  " },
      { "amount" => "200", "unit" => "ml", "name" => "   " }
    ]
    profile["finish_note"] = "  #{"Pour espresso over matcha. " * 50}  "
    recipe.update!(profile:)

    share = PublicRecipeShare.create!(
      workspace: recipe.workspace,
      recipe:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    share.refresh_snapshot!(title: "Public recipe", selected_photo_attachment_ids: [], updated_by: users(:one))

    assert_equal [
      {
        "amount" => "2" * 32,
        "unit" => "m" * 32,
        "name" => ("matcha" * 30).first(120)
      }
    ], share.snapshot.dig("recipe", "ingredients")
    assert_equal ("Pour espresso over matcha. " * 50).first(1_000), share.snapshot.dig("recipe", "finish_note")
  end
end
