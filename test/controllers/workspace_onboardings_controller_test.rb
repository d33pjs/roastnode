require "test_helper"

class WorkspaceOnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user without workspace can create household workspace" do
    user = User.create!(email_address: "new-owner@example.com", password: "password")
    sign_in_as(user)

    assert_difference -> { Workspace.count }, 1 do
      assert_difference -> { Membership.owner.count }, 1 do
        assert_difference -> { ActivityEvent.count }, 1 do
          post workspace_onboarding_path, params: { workspace: { name: "Morning Flat" } }
        end
      end
    end

    workspace = Workspace.order(:created_at).last
    event = ActivityEvent.order(:id).last
    assert_equal "workspace.created", event.action
    assert_redirected_to root_path
    assert_equal workspace, user.reload.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_equal workspace, event.workspace
    assert_equal user, event.actor
    assert_equal workspace, event.subject
    assert_equal "workspace_admin", event.visibility
  end

  test "invalid workspace creation renders onboarding" do
    user = User.create!(email_address: "invalid-owner@example.com", password: "password")
    sign_in_as(user)

    assert_no_difference -> { Workspace.count } do
      post workspace_onboarding_path, params: { workspace: { name: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end
end
