require "test_helper"

class HouseholdInviteTest < ActiveSupport::TestCase
  test "requires email address" do
    invite = HouseholdInvite.new(created_by: users(:one), email_address: "")

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "can't be blank"
  end

  test "requires email address format" do
    invite = HouseholdInvite.new(created_by: users(:one), email_address: "not-an-email")

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "is invalid"
  end

  test "normalizes email address" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "New.Owner@Example.COM")

    assert_equal "new.owner@example.com", invite.email_address
  end

  test "new invite sets token and expiration" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "fresh-owner@example.com")

    assert invite.token.present?
    assert_equal Digest::SHA256.hexdigest(invite.token), invite.token_digest
    assert_equal invite, HouseholdInvite.matching_token(invite.token).first
    assert invite.expires_at.future?
  end

  test "active invite is acceptable only before it is closed" do
    active_invite = household_invites(:active_household_invite)

    assert active_invite.acceptable?
    assert_not household_invites(:expired_household_invite).acceptable?

    active_invite.update!(revoked_at: Time.current)
    assert_not active_invite.acceptable?

    accepted_invite = household_invites(:active_household_invite)
    accepted_invite.update!(revoked_at: nil, accepted_at: Time.current)
    assert_not accepted_invite.acceptable?
  end

  test "revoking invite closes it" do
    invite = household_invites(:active_household_invite)

    invite.revoke!

    assert invite.revoked_at.present?
    assert_not invite.acceptable?
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

  test "accepting stale invite copy does not create another household" do
    first_copy = household_invites(:active_household_invite)
    stale_copy = HouseholdInvite.find(first_copy.id)
    user = User.create!(email_address: first_copy.email_address, password: "password")

    first_copy.accept!(user, workspace: Workspace.new(name: "Morning Flat"))

    assert_no_difference -> { Workspace.count } do
      assert_no_difference -> { Membership.owner.count } do
        assert_raises ActiveRecord::RecordInvalid do
          stale_copy.accept!(user, workspace: Workspace.new(name: "Second Flat"))
        end
      end
    end

    assert_equal "Morning Flat", first_copy.reload.workspace.name
  end

  test "accepting invite rejects persisted workspace without creating membership or changing invite" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: invite.email_address, password: "password")
    existing_workspace = workspaces(:other_household)

    assert_no_difference -> { Membership.count } do
      assert_raises ActiveRecord::RecordInvalid do
        invite.accept!(user, workspace: existing_workspace)
      end
    end

    assert_nil invite.reload.accepted_at
    assert_nil invite.workspace
    assert_nil user.reload.active_workspace
  end
end
