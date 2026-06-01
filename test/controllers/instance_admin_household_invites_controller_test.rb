require "test_helper"

class InstanceAdminHouseholdInvitesControllerTest < ActionDispatch::IntegrationTest
  test "instance admin can create household invite and queue email" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_enqueued_emails 1 do
      assert_difference -> { HouseholdInvite.count }, 1 do
        post instance_admin_household_invites_path, params: {
          household_invite: { email_address: "New.Owner@Example.com" }
        }
      end
    end

    invite = HouseholdInvite.order(:created_at).last
    assert_redirected_to instance_admin_path
    assert_equal "new.owner@example.com", invite.email_address
    assert_equal admin, invite.created_by
  end

  test "instance admin cannot create household invite without email" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_no_enqueued_emails do
      assert_no_difference -> { HouseholdInvite.count } do
        post instance_admin_household_invites_path, params: {
          household_invite: { email_address: "" }
        }
      end
    end

    assert_redirected_to instance_admin_path
    assert_match(/Email address/, flash[:alert])
  end

  test "instance admin cannot create household invite with invalid email" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_no_enqueued_emails do
      assert_no_difference -> { HouseholdInvite.count } do
        post instance_admin_household_invites_path, params: {
          household_invite: { email_address: "not-an-email" }
        }
      end
    end

    assert_redirected_to instance_admin_path
    assert_match(/Email address is invalid/, flash[:alert])
  end

  test "household invite mail enqueue log messages are redacted and truncated" do
    controller = InstanceAdmin::HouseholdInvitesController.new
    message = "SMTP failed password=super-secret access_token=abc123 session:cookie secret_key_base=sekret #{"x" * 300}"

    safe_message = controller.send(:safe_error_message, message)

    assert_includes safe_message, "[REDACTED]"
    assert_no_match(/super-secret|abc123|cookie|sekret/, safe_message)
    assert_operator safe_message.length, :<=, 220
  end

  test "regular user cannot create household invite" do
    sign_in_as(users(:one))

    assert_no_difference -> { HouseholdInvite.count } do
      post instance_admin_household_invites_path, params: {
        household_invite: { email_address: "new-owner@example.com" }
      }
    end

    assert_redirected_to root_path
  end

  test "instance admin can revoke active household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    patch revoke_instance_admin_household_invite_path(invite)

    assert_redirected_to instance_admin_path
    assert invite.reload.revoked_at.present?
  end

  test "instance admin cannot revoke closed household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:expired_household_invite)

    assert_no_changes -> { invite.reload.revoked_at } do
      patch revoke_instance_admin_household_invite_path(invite)
    end

    assert_redirected_to instance_admin_path
    assert_equal I18n.t("instance_admin.household_invites.revoke.unavailable"), flash[:alert]
  end

  test "instance admin can resend active household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    assert_no_difference -> { HouseholdInvite.count } do
      assert_enqueued_email_with HouseholdInvitesMailer, :invite, args: [ invite ] do
        post resend_instance_admin_household_invite_path(invite)
      end
    end

    assert_redirected_to instance_admin_path
  end

  test "instance admin can re-invite closed household invite with fresh token" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)
    invite.update!(revoked_at: 1.minute.ago)

    assert_enqueued_emails 1 do
      assert_difference -> { HouseholdInvite.count }, 1 do
        post reinvite_instance_admin_household_invite_path(invite)
      end
    end

    fresh_invite = HouseholdInvite.order(:created_at).last
    assert_redirected_to instance_admin_path
    assert_equal invite.email_address, fresh_invite.email_address
    assert_not_equal invite.token, fresh_invite.token
    assert fresh_invite.acceptable?
  end
end
