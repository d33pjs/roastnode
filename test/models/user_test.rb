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
end
