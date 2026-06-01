require "test_helper"

class HouseholdInvitesControllerTest < ActionDispatch::IntegrationTest
  test "invalid invite token displays unavailable state" do
    get household_invite_path("missing-token")

    assert_response :not_found
    assert_select "h1", I18n.t("household_invites.show.unavailable_title")
  end

  test "unauthenticated user can view household invite signup form" do
    invite = household_invites(:active_household_invite)

    get household_invite_path(invite.token)

    assert_response :success
    assert_select "h1", I18n.t("household_invites.show.title")
    assert_select "form[action=?]", signup_household_invite_path(invite.token)
    assert_select "input[name=?][readonly=readonly]", "user[email_address]"
    assert_select "input[name=?]", "workspace[name]"
  end

  test "invite signup creates account and separate owned household" do
    invite = household_invites(:active_household_invite)

    assert_difference -> { User.count }, 1 do
      assert_difference -> { Workspace.count }, 1 do
        assert_difference -> { Membership.owner.count }, 1 do
          post signup_household_invite_path(invite.token), params: {
            user: {
              email_address: invite.email_address,
              display_name: "New Owner",
              password: "password",
              password_confirmation: "password"
            },
            workspace: { name: "New Household" }
          }
        end
      end
    end

    user = User.find_by!(email_address: invite.email_address)
    workspace = invite.reload.workspace
    assert_redirected_to root_path
    assert_equal "New Owner", user.display_name
    assert_equal "New Household", workspace.name
    assert_equal workspace, user.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_nil invite.created_by.membership_for(workspace)
    assert_equal user, invite.accepted_by
    assert invite.accepted_at.present?
    assert user.sessions.exists?
  end

  test "successful invite signup clears stored authentication return target" do
    invite = household_invites(:active_household_invite)

    get household_invite_path(invite.token)
    assert_equal household_invite_url(invite.token), request.session[:return_to_after_authenticating]

    post signup_household_invite_path(invite.token), params: {
      user: {
        email_address: invite.email_address,
        password: "password",
        password_confirmation: "password"
      },
      workspace: { name: "New Household" }
    }

    assert_redirected_to root_path
    assert_nil request.session[:return_to_after_authenticating]
  end

  test "invite signup rejects mismatched email without creating household" do
    invite = household_invites(:active_household_invite)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        post signup_household_invite_path(invite.token), params: {
          user: {
            email_address: "other-owner@example.com",
            password: "password",
            password_confirmation: "password"
          },
          workspace: { name: "Other Household" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "signed-in mismatched user cannot use signup endpoint directly" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: "other-owner@example.com", password: "password")
    sign_in_as(user)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        post signup_household_invite_path(invite.token), params: {
          user: {
            email_address: invite.email_address,
            password: "password",
            password_confirmation: "password"
          },
          workspace: { name: "Hijacked Household" }
        }
      end
    end

    assert_redirected_to household_invite_path(invite.token)
    assert_nil invite.reload.accepted_at
  end

  test "invite signup rejects existing account email without accepting invite" do
    invite = household_invites(:active_household_invite)
    invite.update!(email_address: users(:one).email_address)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        post signup_household_invite_path(invite.token), params: {
          user: {
            email_address: users(:one).email_address,
            password: "password",
            password_confirmation: "password"
          },
          workspace: { name: "Duplicate Household" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "invite signup renders invite-level errors" do
    invite = household_invites(:active_household_invite)

    with_household_invite_accept_failure("is no longer available") do
      post signup_household_invite_path(invite.token), params: {
        user: {
          email_address: invite.email_address,
          password: "password",
          password_confirmation: "password"
        },
        workspace: { name: "Stale Household" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "li", "is no longer available"
  end

  test "signed-in matching user can accept invite and create separate household" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: invite.email_address, password: "password")
    sign_in_as(user)

    assert_difference -> { Workspace.count }, 1 do
      assert_difference -> { Membership.owner.count }, 1 do
        post accept_household_invite_path(invite.token), params: {
          workspace: { name: "Existing Account Household" }
        }
      end
    end

    workspace = invite.reload.workspace
    assert_redirected_to root_path
    assert_equal "Existing Account Household", workspace.name
    assert_equal workspace, user.reload.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_nil invite.created_by.membership_for(workspace)
  end

  test "signed-in mismatched user cannot accept invite" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: "other-owner@example.com", password: "password")
    sign_in_as(user)

    assert_no_difference -> { Workspace.count } do
      post accept_household_invite_path(invite.token), params: {
        workspace: { name: "Wrong Household" }
      }
    end

    assert_redirected_to household_invite_path(invite.token)
    assert_nil invite.reload.accepted_at
  end

  private
    def with_household_invite_accept_failure(message)
      original_accept = HouseholdInvite.instance_method(:accept!)

      HouseholdInvite.define_method(:accept!) do |*_args, **_kwargs|
        errors.add(:base, message)
        raise ActiveRecord::RecordInvalid, self
      end

      yield
    ensure
      HouseholdInvite.define_method(:accept!, original_accept)
    end
end
