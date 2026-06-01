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

    patch revoke_instance_admin_household_invite_path(invite.token)

    assert_redirected_to instance_admin_path
    assert invite.reload.revoked_at.present?
  end

  test "instance admin can resend active household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    assert_no_difference -> { HouseholdInvite.count } do
      assert_enqueued_email_with HouseholdInvitesMailer, :invite, args: [ invite ] do
        post resend_instance_admin_household_invite_path(invite.token)
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
        post reinvite_instance_admin_household_invite_path(invite.token)
      end
    end

    fresh_invite = HouseholdInvite.order(:created_at).last
    assert_redirected_to instance_admin_path
    assert_equal invite.email_address, fresh_invite.email_address
    assert_not_equal invite.token, fresh_invite.token
    assert fresh_invite.acceptable?
  end
end
