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
end
