class WorkspaceInvitesMailer < ApplicationMailer
  def invite(workspace_invite)
    @workspace_invite = workspace_invite

    mail(
      subject: t(".subject", workspace: @workspace_invite.workspace.name),
      to: @workspace_invite.email_address
    )
  end
end
