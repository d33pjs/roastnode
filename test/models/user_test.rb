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
end
