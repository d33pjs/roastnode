require "test_helper"

class WorkspaceInvitesControllerTest < ActionDispatch::IntegrationTest
  test "workspace owner can view invite management" do
    sign_in_as(users(:one))

    get workspace_invites_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_invites.index.title")
    assert_select "td", text: "member"
    assert_select "input[value=?]", workspace_invite_url(workspace_invites(:member_invite).token)
    assert_select "form[action=?]", workspace_invites_path
  end

  test "workspace owner can create invite" do
    sign_in_as(users(:one))

    assert_difference -> { workspaces(:household).workspace_invites.count }, 1 do
      post workspace_invites_path, params: { workspace_invite: { email_address: "Friend@Example.com", role: "member" } }
    end

    invite = workspaces(:household).workspace_invites.order(:created_at).last
    assert_redirected_to workspace_invites_path
    assert_equal "friend@example.com", invite.email_address
    assert_equal "member", invite.role
    assert_equal users(:one), invite.created_by
  end

  test "workspace member cannot create invite" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).workspace_invites.count } do
      post workspace_invites_path, params: { workspace_invite: { email_address: "friend@example.com", role: "member" } }
    end

    assert_redirected_to root_path
  end

  test "workspace owner can revoke invite" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)

    patch revoke_workspace_invite_path(invite.token)

    assert_redirected_to workspace_invites_path
    assert invite.reload.revoked_at.present?
  end

  test "invalid invite token displays unavailable state" do
    sign_in_as(users(:two))

    get workspace_invite_path("missing-token")

    assert_response :not_found
    assert_select "h1", I18n.t("workspace_invites.show.unavailable_title")
  end

  test "signed-in user can accept invite" do
    user = User.create!(email_address: "new-member@example.com", password: "password")
    invite = workspace_invites(:member_invite)
    sign_in_as(user)

    assert_difference -> { user.memberships.count }, 1 do
      post accept_workspace_invite_path(invite.token)
    end

    membership = user.membership_for(workspaces(:household))
    assert_redirected_to root_path
    assert_equal "member", membership.role
    assert_equal workspaces(:household), user.reload.active_workspace
    assert_equal user, invite.reload.accepted_by
    assert invite.accepted_at.present?
  end
end
