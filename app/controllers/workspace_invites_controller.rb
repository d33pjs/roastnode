class WorkspaceInvitesController < ApplicationController
  before_action :authorize_workspace_admin!, only: %i[index create revoke]
  before_action :set_workspace_invite, only: :revoke

  def index
    @workspace_invites = current_workspace.workspace_invites.order(created_at: :desc)
    @workspace_invite = current_workspace.workspace_invites.new(role: "member")
  end

  def show
    @workspace_invite = WorkspaceInvite.find_by(token: params[:token])

    unless @workspace_invite&.acceptable?
      @workspace_invite = nil
      response.status = :not_found
    end
  end

  def create
    current_workspace.workspace_invites.create!(workspace_invite_params.merge(created_by: Current.user))

    redirect_to workspace_invites_path, notice: t(".created")
  end

  def accept
    @workspace_invite = WorkspaceInvite.find_by(token: params[:token])

    unless @workspace_invite&.acceptable?
      return redirect_to workspace_invite_path(params[:token]), alert: t(".unavailable")
    end

    @workspace_invite.accept!(Current.user)
    Current.user.update!(active_workspace: @workspace_invite.workspace)

    redirect_to root_path, notice: t(".accepted", workspace: @workspace_invite.workspace.name)
  end

  def revoke
    @workspace_invite.revoke!

    redirect_to workspace_invites_path, notice: t(".revoked")
  end

  private
    def set_workspace_invite
      @workspace_invite = current_workspace.workspace_invites.find_by!(token: params[:token])
    end

    def workspace_invite_params
      params.expect(workspace_invite: [ :email_address, :role ])
    end
end
