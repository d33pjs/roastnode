require "test_helper"

class WorkspaceMembershipManagerTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "owner can change non owner role" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    event = assert_activity_event(
      action: "membership.role_changed", workspace: workspaces(:household), actor: users(:one), subject: memberships(:member)
    ) do
      manager.update_role(memberships(:member), "viewer")
    end

    assert_equal({ "from_role" => "member", "to_role" => "viewer" }, event.metadata.slice("from_role", "to_role"))
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

    event = assert_activity_event(
      action: "membership.ownership_transferred", workspace: workspaces(:household), actor: users(:one), subject: memberships(:member)
    ) do
      manager.transfer_ownership(memberships(:member))
    end

    assert_equal({ "from_role" => "owner", "to_role" => "owner" }, event.metadata.slice("from_role", "to_role"))
    assert_equal "admin", memberships(:owner).reload.role
    assert_equal "owner", memberships(:member).reload.role
  end

  test "removing a member clears their active workspace only when needed" do
    workspace = workspaces(:household)
    user = users(:two)
    user.update!(active_workspace: workspace)
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: memberships(:owner))

    removed_membership = memberships(:member)
    event = assert_activity_event(action: "membership.removed", workspace:, actor: users(:one)) do
      manager.remove(removed_membership)
    end

    assert_equal removed_membership.id, event.subject_id
    assert_nil event.subject
    assert_equal "member", event.metadata.fetch("role")
    assert_nil user.reload.active_workspace
    assert_not Membership.exists?(memberships(:member).id)
  end

  test "removing a member refreshes public recipient snapshots before recording activity" do
    workspace = workspaces(:household)
    recipient = users(:two)
    recipient.update!(active_workspace: workspace, display_name: "Petra")
    avatar = attach_named_photo(recipient, :avatar, filename: "private-petra.jpg")
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: recipient)
    brew_share = create_public_brew_share(brew)
    bean_share = create_public_bean_share(brew.bean)
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: memberships(:owner))

    assert_activity_event(action: "membership.removed", workspace:, actor: users(:one)) do
      manager.remove(memberships(:member))
    end

    expected_recipient = { "kind" => "household_member", "display_label" => "Petra" }
    assert_equal expected_recipient, brew_share.reload.snapshot.dig("brew", "recipient")
    assert_equal expected_recipient, bean_share.reload.snapshot.fetch("brews").first.fetch("recipient")
    assert_not_includes brew_share.snapshot.fetch("public_media").pluck("attachment_id"), avatar.id
    assert_not_includes bean_share.snapshot.fetch("public_media").pluck("attachment_id"), avatar.id
    assert_nil recipient.reload.active_workspace
    assert_not Membership.exists?(memberships(:member).id)
  end

  test "recipient snapshot refresh failure rolls membership active workspace snapshots and activity back" do
    workspace = workspaces(:household)
    recipient = users(:two)
    recipient.update!(active_workspace: workspace, display_name: "Petra")
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: recipient)
    brew_share = create_public_brew_share(brew)
    bean_share = create_public_bean_share(brew.bean)
    original_brew_snapshot = brew_share.snapshot.deep_dup
    original_bean_snapshot = bean_share.snapshot.deep_dup
    original_activity_count = ActivityEvent.count
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: memberships(:owner))

    error = assert_raises(RuntimeError) do
      with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_for, ->(_record) { raise "refresh failed" }) do
        manager.remove(memberships(:member))
      end
    end

    assert_equal "refresh failed", error.message
    assert Membership.exists?(memberships(:member).id)
    assert_equal workspace, recipient.reload.active_workspace
    assert_equal original_brew_snapshot, brew_share.reload.snapshot
    assert_equal original_bean_snapshot, bean_share.reload.snapshot
    assert_equal original_activity_count, ActivityEvent.count
  end

  private
    def create_public_brew_share(brew)
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def create_public_bean_share(bean)
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
