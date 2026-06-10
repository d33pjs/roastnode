require "test_helper"

class WorkspaceInviteTest < ActiveSupport::TestCase
  test "valid invite is available for acceptance" do
    invite = workspace_invites(:member_invite)

    assert invite.acceptable?
  end

  test "new invite stores a token digest for lookup" do
    invite = workspaces(:household).workspace_invites.create!(created_by: users(:one), role: "member")

    assert invite.token.present?
    assert_equal Digest::SHA256.hexdigest(invite.token), invite.token_digest
    assert_equal invite, WorkspaceInvite.matching_token(invite.token).first
  end

  test "expired invite is not available for acceptance" do
    invite = workspace_invites(:expired_invite)

    assert_not invite.acceptable?
  end

  test "blank email invite is acceptable for any user" do
    invite = workspace_invites(:member_invite)

    assert invite.acceptable_for?(users(:two))
  end

  test "email-bound invite is acceptable for matching normalized user email" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "Friend@Example.com")
    user = User.create!(email_address: "friend@example.com", password: "password")

    assert invite.acceptable_for?(user)
  end

  test "email-bound invite is not acceptable for a different user email" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")
    user = User.create!(email_address: "other@example.com", password: "password")

    assert_not invite.acceptable_for?(user)
    assert_raises ActiveRecord::RecordInvalid do
      invite.accept!(user)
    end
    assert_nil invite.reload.accepted_at
  end

  test "accepting invite creates membership with invite role" do
    invite = workspace_invites(:member_invite)
    user = users(:two)
    user.memberships.where(workspace: invite.workspace).delete_all

    membership = invite.accept!(user)

    assert_equal invite.workspace, membership.workspace
    assert_equal "member", membership.role
    assert_equal user, invite.reload.accepted_by
    assert_not invite.acceptable?
  end

  test "accepting invite does not downgrade existing membership" do
    invite = workspace_invites(:member_invite)
    user = users(:one)

    membership = invite.accept!(user)

    assert_equal "owner", membership.reload.role
    assert_equal user, invite.reload.accepted_by
  end
end
