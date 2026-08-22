require "test_helper"

class BrewRecipientPresenterTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "presents every recipient kind with fixed copy colors icons and byline" do
    brew = brews(:morning_espresso)
    brew.user.update!(display_name: "Jens")
    users(:two).update!(display_name: "Petra")

    self_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
    assert_equal "For me", self_view.badge_text
    assert_equal "Logged by Jens for themself", self_view.byline_text
    assert_equal "person", self_view.icon_name
    assert_includes self_view.badge_classes, "bg-sky-100"

    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    member_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
    assert_equal "For Petra", member_view.badge_text
    assert_equal "Logged by Jens for Petra", member_view.byline_text
    assert_equal "home", member_view.icon_name
    assert_includes member_view.badge_classes, "bg-orange-100"

    brew.update!(recipient_kind: "guest", recipient_name: "Anna")
    named_guest_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
    assert_equal "For Anna", named_guest_view.badge_text
    assert_equal "groups", named_guest_view.icon_name
    assert_includes named_guest_view.badge_classes, "bg-emerald-100"

    brew.update!(recipient_kind: "guest", recipient_name: nil)
    assert_equal "For a guest", BrewRecipientPresenter.new(brew:, workspace: brew.workspace).badge_text
  end

  test "keeps former recipient label but suppresses no-longer-authorized recipient avatar" do
    brew = brews(:morning_espresso)
    users(:two).update!(display_name: "Petra")
    avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))

    presenter = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
    assert_equal avatar, presenter.recipient_avatar_attachment
    assert_same presenter.recipient_avatar_attachment, presenter.recipient_avatar_attachment

    memberships(:member).destroy!
    former_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace.reload)
    assert_equal "For Petra", former_view.badge_text
    assert_nil former_view.recipient_avatar_attachment
  end

  test "keeps former logger label but suppresses no-longer-authorized logger avatar" do
    brew = brews(:morning_espresso)
    brew.user.update!(display_name: "Jens")
    attach_named_photo(brew.user, :avatar, filename: "jens.jpg")

    assert BrewRecipientPresenter.new(brew:, workspace: brew.workspace).logger_avatar_attachment
    memberships(:owner).destroy!

    former_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace.reload)
    assert_equal "Logged by Jens for themself", former_view.byline_text
    assert_nil former_view.logger_avatar_attachment
  end
end
