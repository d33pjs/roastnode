require "test_helper"

class WorkspacePolicyTest < ActiveSupport::TestCase
  test "owner and admin can manage workspace" do
    workspace = workspaces(:household)
    owner = memberships(:owner)
    admin = Membership.create!(workspace:, user: User.create!(
      email_address: "admin@example.com",
      password: "password"
    ), role: :admin)

    assert WorkspacePolicy.new(owner).manage?
    assert WorkspacePolicy.new(admin).manage?
  end

  test "member can write normal workspace data but cannot manage" do
    policy = WorkspacePolicy.new(memberships(:member))

    assert policy.write?
    assert_not policy.manage?
  end

  test "viewer is read only" do
    viewer = Membership.create!(workspace: workspaces(:household), user: User.create!(
      email_address: "viewer@example.com",
      password: "password"
    ), role: :viewer)
    policy = WorkspacePolicy.new(viewer)

    assert policy.read?
    assert_not policy.write?
    assert_not policy.manage?
  end

  test "missing membership has no access" do
    policy = WorkspacePolicy.new(nil)

    assert_not policy.read?
    assert_not policy.write?
    assert_not policy.manage?
  end
end
