require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "display_label uses profile display name when present" do
    user = User.new(email_address: "jens@example.com", display_name: "Jens")

    assert_equal "Jens", user.display_label
  end

  test "display_label falls back to unknown username" do
    user = User.new(email_address: "jens.actinoide@example.com")

    assert_equal "unknown username", user.display_label
  end

  test "default landing screen is constrained to supported screens" do
    user = users(:one)

    user.default_landing_screen = "log_espresso"
    assert_predicate user, :valid?
    assert_predicate user, :default_landing_log_espresso?

    user.default_landing_screen = "side_quest"
    assert_not_predicate user, :valid?
  end

  test "default brew focus field is constrained to supported fields" do
    user = users(:one)

    user.default_brew_focus_field = "dose_grams"
    assert_predicate user, :valid?

    user.default_brew_focus_field = "rating"
    assert_not_predicate user, :valid?
  end

  test "display formatting preferences are constrained to supported values" do
    user = users(:one)

    user.number_format = "dot_decimal"
    user.time_format = "us_12h_seconds"
    assert_predicate user, :valid?

    user.number_format = "middle_earth"
    assert_not_predicate user, :valid?

    user.number_format = "comma_decimal"
    user.time_format = "sundial"
    assert_not_predicate user, :valid?
  end

  test "theme is constrained to supported values" do
    user = users(:one)

    user.theme = "dark"
    assert_predicate user, :valid?
    assert_predicate user, :dark_theme?

    user.theme = "sepia"
    assert_not_predicate user, :valid?
  end

  test "ensure active workspace only persists workspace pointer" do
    user = users(:one)
    user.update!(active_workspace: nil)
    user.display_name = "a" * 81

    assert_equal workspaces(:household), user.ensure_active_workspace!
    assert_equal "a" * 81, user.display_name
    assert_nil user.reload.display_name
    assert_equal workspaces(:household), user.active_workspace
  end

  test "hidden brew field names keep only supported fields" do
    user = users(:one)

    user.hidden_brew_field_names = [ "notes", "unsupported", "", "rating", "notes" ]

    assert_equal %w[notes rating], user.hidden_brew_field_names
  end

  test "enabled brew methods default to espresso and quick drip and require one method" do
    user = User.new(email_address: "methods@example.com", password: "secret123")

    assert_equal %w[espresso quick_drip], user.enabled_brew_methods

    user.enabled_brew_methods = [ "quick_drip", "unsupported", "", "quick_drip" ]
    assert_equal %w[quick_drip], user.enabled_brew_methods
    assert_predicate user, :valid?

    user.enabled_brew_methods = []
    assert_not_predicate user, :valid?
    assert_includes user.errors[:enabled_brew_methods], "must include at least one method"
  end

  test "grams per coffee spoon accepts blank or positive decimal values" do
    user = users(:one)

    user.grams_per_coffee_spoon = nil
    assert_predicate user, :valid?

    user.grams_per_coffee_spoon = 4.5
    assert_predicate user, :valid?

    user.grams_per_coffee_spoon = 0
    assert_not_predicate user, :valid?
  end

  test "generates stable webauthn user id on demand" do
    user = users(:one)
    assert_nil user.webauthn_user_id

    generated_id = user.ensure_webauthn_user_id!

    assert generated_id.present?
    assert_equal generated_id, user.reload.webauthn_user_id
    assert_equal generated_id, user.ensure_webauthn_user_id!
  end

  test "passkey second factor requires at least one passkey" do
    user = users(:two)

    user.passkey_second_factor_enabled = true

    assert_not user.valid?
    assert_includes user.errors[:passkey_second_factor_enabled], "requires at least one passkey"
  end
end
