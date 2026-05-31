require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "member list shows only active workspace members" do
    sign_in_as(users(:one))

    get memberships_path

    assert_response :success
    assert_select "h1", I18n.t("memberships.index.title")
    assert_select "td", text: users(:one).email_address
    assert_select "td", text: users(:two).email_address
  end

  test "non-member cannot read another workspace through active workspace id" do
    user = users(:one)
    user.update!(active_workspace: workspaces(:other_household))
    sign_in_as(user)

    get memberships_path

    assert_redirected_to root_path
    assert_not_equal workspaces(:other_household), user.reload.active_workspace
  end

  test "owner can update member role" do
    sign_in_as(users(:one))

    patch membership_path(memberships(:member)), params: { membership: { role: "viewer" } }

    assert_redirected_to memberships_path
    assert_equal "viewer", memberships(:member).reload.role
  end

  test "admin can update member and viewer roles but not admins" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "admin-controller@example.com", password: "password")
    admin_membership = Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    other_admin = Membership.create!(workspace:, user: User.create!(email_address: "other-admin@example.com", password: "password"), role: "admin")
    sign_in_as(admin)

    patch membership_path(memberships(:member)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "viewer", memberships(:member).reload.role

    patch membership_path(other_admin), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "admin", other_admin.reload.role
    assert_equal "admin", admin_membership.reload.role
  end

  test "owner can remove non owner member" do
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:one))

    delete membership_path(memberships(:member))

    assert_redirected_to memberships_path
    assert_not Membership.exists?(memberships(:member).id)
    assert_nil users(:two).reload.active_workspace
  end

  test "member cannot update or remove memberships" do
    actor = users(:two)
    actor.update!(active_workspace: workspaces(:household))
    sign_in_as(actor)

    patch membership_path(memberships(:owner)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "owner", memberships(:owner).reload.role

    delete membership_path(memberships(:owner))
    assert_redirected_to memberships_path
    assert Membership.exists?(memberships(:owner).id)
  end

  test "membership from another workspace cannot be changed or removed" do
    sign_in_as(users(:one))

    patch membership_path(memberships(:other_owner)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "owner", memberships(:other_owner).reload.role

    delete membership_path(memberships(:other_owner))
    assert_redirected_to memberships_path
    assert Membership.exists?(memberships(:other_owner).id)
  end
end
