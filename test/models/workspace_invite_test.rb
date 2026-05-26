require "test_helper"

class WorkspaceInviteTest < ActiveSupport::TestCase
  test "valid invite is available for acceptance" do
    invite = workspace_invites(:member_invite)

    assert invite.acceptable?
  end

  test "expired invite is not available for acceptance" do
    invite = workspace_invites(:expired_invite)

    assert_not invite.acceptable?
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
end
