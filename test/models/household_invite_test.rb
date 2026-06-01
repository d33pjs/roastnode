require "test_helper"

class HouseholdInviteTest < ActiveSupport::TestCase
  test "requires email address" do
    invite = HouseholdInvite.new(created_by: users(:one), email_address: "")

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "can't be blank"
  end

  test "normalizes email address" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "New.Owner@Example.COM")

    assert_equal "new.owner@example.com", invite.email_address
  end

  test "new invite sets token and expiration" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "fresh-owner@example.com")

    assert invite.token.present?
    assert invite.expires_at.future?
  end

  test "active invite is acceptable only before it is closed" do
    assert household_invites(:active_household_invite).acceptable?
    assert_not household_invites(:expired_household_invite).acceptable?
  end

  test "invite is acceptable only for matching normalized email" do
    invite = household_invites(:active_household_invite)
    matching = User.create!(email_address: "NEW-OWNER@example.com", password: "password")
    other = User.create!(email_address: "other-owner@example.com", password: "password")

    assert invite.acceptable_for?(matching)
    assert_not invite.acceptable_for?(other)
  end

  test "accepting invite creates a separate household owned by recipient" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: invite.email_address, password: "password")
    workspace = Workspace.new(name: "Morning Flat")

    assert_difference -> { Workspace.count }, 1 do
      assert_difference -> { Membership.owner.count }, 1 do
        invite.accept!(user, workspace:)
      end
    end

    created_workspace = invite.reload.workspace
    assert_equal "Morning Flat", created_workspace.name
    assert_equal "household", created_workspace.kind
    assert_equal "EUR", created_workspace.default_currency
    assert_equal user, invite.accepted_by
    assert invite.accepted_at.present?
    assert_equal created_workspace, user.reload.active_workspace
    assert_equal "owner", user.membership_for(created_workspace).role
    assert_nil users(:one).membership_for(created_workspace)
  end

  test "accepting invite rejects mismatched email without creating household" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: "other-owner@example.com", password: "password")

    assert_no_difference -> { Workspace.count } do
      assert_raises ActiveRecord::RecordInvalid do
        invite.accept!(user, workspace: Workspace.new(name: "Other Flat"))
      end
    end

    assert_nil invite.reload.accepted_at
  end
end
