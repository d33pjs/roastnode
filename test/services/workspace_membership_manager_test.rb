require "test_helper"

class WorkspaceMembershipManagerTest < ActiveSupport::TestCase
  test "owner can change non owner role" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    result = manager.update_role(memberships(:member), "viewer")

    assert result.success?
    assert_equal "viewer", memberships(:member).reload.role
  end

  test "admin can only change member and viewer roles" do
    workspace = workspaces(:household)
    admin_user = User.create!(email_address: "admin-service@example.com", password: "password")
    admin = Membership.create!(workspace:, user: admin_user, role: "admin")
    viewer_user = User.create!(email_address: "viewer-service@example.com", password: "password")
    viewer = Membership.create!(workspace:, user: viewer_user, role: "viewer")
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: admin)

    assert manager.update_role(memberships(:member), "viewer").success?
    assert_equal "viewer", memberships(:member).reload.role

    assert manager.update_role(viewer, "member").success?
    assert_equal "member", viewer.reload.role

    result = manager.update_role(admin, "viewer")
    assert_not result.success?
    assert_equal :unauthorized, result.error
    assert_equal "admin", admin.reload.role
  end

  test "last owner cannot be demoted or removed" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    demotion = manager.update_role(memberships(:owner), "admin")
    removal = manager.remove(memberships(:owner))

    assert_not demotion.success?
    assert_equal :last_owner, demotion.error
    assert_not removal.success?
    assert_equal :last_owner, removal.error
    assert_equal "owner", memberships(:owner).reload.role
  end

  test "ownership transfer promotes target and demotes actor" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    result = manager.transfer_ownership(memberships(:member))

    assert result.success?
    assert_equal "admin", memberships(:owner).reload.role
    assert_equal "owner", memberships(:member).reload.role
  end

  test "removing a member clears their active workspace only when needed" do
    workspace = workspaces(:household)
    user = users(:two)
    user.update!(active_workspace: workspace)
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: memberships(:owner))

    result = manager.remove(memberships(:member))

    assert result.success?
    assert_nil user.reload.active_workspace
    assert_not Membership.exists?(memberships(:member).id)
  end
end
