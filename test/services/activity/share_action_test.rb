require "test_helper"

class Activity::ShareActionTest < ActiveSupport::TestCase
  test "resolves create and enabled transitions to one share action" do
    cases = [
      [ { was_new: true, was_enabled: false, enabled: false }, "public_brew_share.created" ],
      [ { was_new: true, was_enabled: false, enabled: true }, "public_brew_share.published" ],
      [ { was_new: false, was_enabled: false, enabled: true }, "public_brew_share.published" ],
      [ { was_new: false, was_enabled: true, enabled: false }, "public_brew_share.disabled" ],
      [ { was_new: false, was_enabled: true, enabled: true }, "public_brew_share.updated" ],
      [ { was_new: false, was_enabled: false, enabled: false }, "public_brew_share.updated" ]
    ]

    cases.each do |state, expected|
      assert_equal expected, Activity::ShareAction.resolve(prefix: "public_brew_share", **state)
    end
  end
end
