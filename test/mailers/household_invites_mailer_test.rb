require "test_helper"

class HouseholdInvitesMailerTest < ActionMailer::TestCase
  test "invite email includes recipient and household invite link" do
    invite = household_invites(:active_household_invite)

    mail = HouseholdInvitesMailer.invite(invite)
    invite_url = Rails.application.routes.url_helpers.household_invite_url(invite.token, host: "example.com")

    assert_equal "Create your Roastnode household", mail.subject
    assert_equal [ invite.email_address ], mail.to
    assert_includes mail.text_part.body.to_s, invite.email_address
    assert_includes mail.text_part.body.to_s, invite_url
    assert_includes mail.html_part.body.to_s, invite_url
  end

  test "invite email uses configured from address" do
    invite = household_invites(:active_household_invite)

    with_mail_from_address("Roastnode <invites@coffee.example.test>") do
      mail = HouseholdInvitesMailer.invite(invite)

      assert_equal [ "invites@coffee.example.test" ], mail.from
    end
  end

  private
    def with_mail_from_address(address)
      roastnode_config = Rails.configuration.x.roastnode
      previous_address = roastnode_config.mail_from_address
      roastnode_config.mail_from_address = address

      yield
    ensure
      roastnode_config.mail_from_address = previous_address
    end
end
