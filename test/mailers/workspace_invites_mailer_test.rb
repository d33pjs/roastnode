require "test_helper"

class WorkspaceInvitesMailerTest < ActionMailer::TestCase
  test "invite email includes workspace name and invite link" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    mail = WorkspaceInvitesMailer.invite(invite)
    invite_url = Rails.application.routes.url_helpers.workspace_invite_url(invite.token, host: "example.com")

    assert_equal [ "friend@example.com" ], mail.to
    assert_equal "Join #{invite.workspace.name} on Roastnode", mail.subject
    assert_includes mail.text_part.body.to_s, invite.workspace.name
    assert_includes mail.text_part.body.to_s, invite_url
    assert_includes mail.html_part.body.to_s, invite_url
  end

  test "invite email uses configured from address" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    with_mail_from_address("Roastnode <invites@coffee.example.test>") do
      mail = WorkspaceInvitesMailer.invite(invite)

      assert_equal [ "invites@coffee.example.test" ], mail.from
      assert_includes mail[:from].to_s, "Roastnode"
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
