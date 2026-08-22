require "test_helper"

class WorkspaceInvitesControllerTest < ActionDispatch::IntegrationTest
  test "invite lifecycle is admin-visible and stores neither email nor token" do
    sign_in_as(users(:one))
    event = assert_activity_event(action: "workspace_invite.created", workspace: workspaces(:household), actor: users(:one)) do
      post workspace_invites_path, params: { workspace_invite: { email_address: "invitee@example.test", role: "member" } }
    end

    assert_equal "workspace_admin", event.visibility
    assert_equal "member", event.metadata.fetch("role")
    assert_no_match(/invitee@example|token|http/i, event.metadata.to_json)
  end

  test "workspace owner can view invite management" do
    sign_in_as(users(:one))

    get workspace_invites_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_invites.index.title")
    assert_select "td", text: "member"
    assert_select "input[value=?]", workspace_invite_url(workspace_invites(:member_invite).token)
    assert_select "form[action=?]", workspace_invites_path
  end

  test "active invite revoke action remains reachable in the scrollable invite list" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)

    get workspace_invites_path

    assert_response :success
    assert_select "div.overflow-x-auto" do
      assert_select "form[action=?]", revoke_workspace_invite_path(invite.token)
    end
  end

  test "workspace owner can see accepted invite details" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)
    accepted_at = Time.find_zone("Europe/Berlin").local(2026, 6, 7, 10, 15, 0)
    invite.update!(email_address: "friend@example.com", accepted_by: users(:two), accepted_at:)

    get workspace_invites_path

    assert_response :success
    assert_select "[data-testid=workspace-invite-#{invite.id}]" do
      assert_select "p", text: I18n.t("workspace_invites.index.accepted")
      assert_select "p", text: I18n.t(
        "workspace_invites.index.accepted_by",
        user: users(:two).display_label,
        time: I18n.l(accepted_at, format: :european_seconds)
      )
    end
  end

  test "workspace owner can create invite" do
    sign_in_as(users(:one))

    assert_enqueued_emails 1 do
      assert_difference -> { workspaces(:household).workspace_invites.count }, 1 do
        post workspace_invites_path, params: { workspace_invite: { email_address: "Friend@Example.com", role: "member" } }
      end
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

  test "workspace owner can resend active email-bound invite" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    get workspace_invites_path
    assert_response :success
    assert_select "form[action=?]", resend_workspace_invite_path(invite.token)

    assert_no_difference -> { workspaces(:household).workspace_invites.count } do
      assert_enqueued_email_with WorkspaceInvitesMailer, :invite, args: [ invite ] do
        assert_activity_event(
          action: "workspace_invite.resent", workspace: invite.workspace, actor: users(:one), subject: invite
        ) do
          post resend_workspace_invite_path(invite.token)
        end
      end
    end

    assert_redirected_to workspace_invites_path
  end

  test "workspace owner can re-invite closed email-bound invite with fresh token" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com", revoked_at: 1.minute.ago)

    get workspace_invites_path
    assert_response :success
    assert_select "form[action=?]", reinvite_workspace_invite_path(invite.token)

    assert_enqueued_emails 1 do
      assert_difference -> { workspaces(:household).workspace_invites.count }, 1 do
        assert_activity_event(action: "workspace_invite.reinvited", workspace: invite.workspace, actor: users(:one)) do
          post reinvite_workspace_invite_path(invite.token)
        end
      end
    end

    fresh_invite = workspaces(:household).workspace_invites.order(:created_at).last
    assert_redirected_to workspace_invites_path
    assert_equal "friend@example.com", fresh_invite.email_address
    assert_equal invite.role, fresh_invite.role
    assert_not_equal invite.token, fresh_invite.token
    assert fresh_invite.acceptable?
  end

  test "blank-email invites keep manual copy fallback without send actions" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: nil)

    get workspace_invites_path

    assert_response :success
    assert_select "input[value=?]", workspace_invite_url(invite.token)
    assert_select "form[action=?]", resend_workspace_invite_path(invite.token), count: 0
    assert_select "form[action=?]", reinvite_workspace_invite_path(invite.token), count: 0
  end

  test "workspace member cannot resend or re-invite" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    assert_no_enqueued_emails do
      assert_no_difference -> { workspaces(:household).workspace_invites.count } do
        post resend_workspace_invite_path(invite.token)
      end
    end
    assert_redirected_to root_path

    invite.update!(revoked_at: 1.minute.ago)

    assert_no_enqueued_emails do
      assert_no_difference -> { workspaces(:household).workspace_invites.count } do
        post reinvite_workspace_invite_path(invite.token)
      end
    end
    assert_redirected_to root_path
  end

  test "workspace owner can revoke invite" do
    sign_in_as(users(:one))
    invite = workspace_invites(:member_invite)

    assert_activity_event(
      action: "workspace_invite.revoked", workspace: invite.workspace, actor: users(:one), subject: invite
    ) do
      patch revoke_workspace_invite_path(invite.token)
    end

    assert_redirected_to workspace_invites_path
    assert invite.reload.revoked_at.present?
  end

  test "invalid invite token displays unavailable state" do
    sign_in_as(users(:two))

    get workspace_invite_path("missing-token")

    assert_response :not_found
    assert_select "h1", I18n.t("workspace_invites.show.unavailable_title")
  end

  test "workspace invite request path and redirects redact bearer tokens for logs" do
    invite = workspace_invites(:member_invite)
    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/workspace_invites/#{invite.token}/accept?token=secret")
    )
    request.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    assert_equal "/workspace_invites/[FILTERED]/accept?token=[FILTERED]", request.filtered_path

    sign_in_as(users(:two))
    invite.update!(email_address: "friend@example.com")

    post accept_workspace_invite_path(invite.token)

    assert_redirected_to workspace_invite_path(invite.token)
    assert_equal "[FILTERED]", response.filtered_location
  end

  test "workspace invite controller lookup uses token digest instead of raw token in SQL binds" do
    invite = workspace_invites(:member_invite)

    sql_values = collect_sql_bind_values do
      get workspace_invite_path(invite.token)
    end

    assert_response :success
    assert_not_includes sql_values, invite.token
    assert_includes sql_values, WorkspaceInvite.token_digest_for(invite.token)
  end

  test "unauthenticated user can view invite signup form" do
    invite = workspace_invites(:member_invite)

    get workspace_invite_path(invite.token)

    assert_response :success
    assert_select "h1", I18n.t("workspace_invites.show.title", workspace: invite.workspace.name)
    assert_select "form[action=?]", signup_workspace_invite_path(invite.token)
    assert_select "input[name=?]", "user[display_name]"
  end

  test "invite signup creates account with optional username accepts invite and starts session" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "Friend@Example.com")

    before_event_ids = ActivityEvent.pluck(:id)
    assert_difference -> { User.count }, 1 do
      assert_difference -> { Membership.count }, 1 do
        post signup_workspace_invite_path(invite.token), params: {
          user: {
            email_address: "friend@example.com",
            display_name: "Friendly Barista",
            password: "password",
            password_confirmation: "password"
          }
        }
      end
    end

    user = User.find_by!(email_address: "friend@example.com")
    assert_redirected_to root_path
    assert_equal "Friendly Barista", user.display_name
    assert_equal workspaces(:household), user.active_workspace
    assert_equal "member", user.membership_for(workspaces(:household)).role
    assert_equal user, invite.reload.accepted_by
    assert invite.accepted_at.present?
    assert user.sessions.exists?
    events = ActivityEvent.where.not(id: before_event_ids).order(:id).to_a
    assert_equal %w[session.signed_in workspace_invite.accepted], events.map(&:action).sort
    assert events.all? { |event| event.workspace == workspaces(:household) && event.actor == user }
    assert_equal "invited_signup", events.find { |event| event.action == "session.signed_in" }.metadata.fetch("authentication_method")
  end

  test "invite signup rejects mismatched email-bound invite" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Membership.count } do
        post signup_workspace_invite_path(invite.token), params: {
          user: {
            email_address: "other@example.com",
            password: "password",
            password_confirmation: "password"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "invite signup rejects existing account email without accepting invite" do
    invite = workspace_invites(:member_invite)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Membership.count } do
        post signup_workspace_invite_path(invite.token), params: {
          user: {
            email_address: users(:one).email_address,
            password: "password",
            password_confirmation: "password"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "signed-in user can accept invite" do
    user = User.create!(email_address: "new-member@example.com", password: "password")
    invite = workspace_invites(:member_invite)
    sign_in_as(user)

    assert_difference -> { user.memberships.count }, 1 do
      assert_activity_event(action: "workspace_invite.accepted", workspace: invite.workspace, actor: user, subject: invite) do
        post accept_workspace_invite_path(invite.token)
      end
    end

    membership = user.membership_for(workspaces(:household))
    assert_redirected_to root_path
    assert_equal "member", membership.role
    assert_equal workspaces(:household), user.reload.active_workspace
    assert_equal user, invite.reload.accepted_by
    assert invite.accepted_at.present?
  end

  test "signed-in user cannot accept email-bound invite for another address" do
    user = User.create!(email_address: "other@example.com", password: "password")
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")
    sign_in_as(user)

    assert_no_difference -> { user.memberships.count } do
      post accept_workspace_invite_path(invite.token)
    end

    assert_redirected_to workspace_invite_path(invite.token)
    assert_nil invite.reload.accepted_at
  end

  private
    def collect_sql_bind_values
      values = []
      callback = lambda do |_name, _started, _finished, _unique_id, payload|
        next if payload[:name] == "SCHEMA"

        values.concat(Array(payload[:binds]).map { |bind| bind.value_for_database.to_s })
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      values
    end
end
