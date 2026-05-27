class WorkspaceInvitesController < ApplicationController
  allow_unauthenticated_access only: %i[show signup]

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
    else
      prepare_invite_signup
    end
  end

  def create
    current_workspace.workspace_invites.create!(workspace_invite_params.merge(created_by: Current.user))

    redirect_to workspace_invites_path, notice: t(".created")
  end

  def accept
    @workspace_invite = WorkspaceInvite.find_by(token: params[:token])

    unless @workspace_invite&.acceptable_for?(Current.user)
      return redirect_to workspace_invite_path(params[:token]), alert: t(".unavailable")
    end

    @workspace_invite.accept!(Current.user)
    Current.user.update!(active_workspace: @workspace_invite.workspace)

    redirect_to root_path, notice: t(".accepted", workspace: @workspace_invite.workspace.name)
  end

  def signup
    @workspace_invite = WorkspaceInvite.find_by(token: params[:token])

    unless @workspace_invite&.acceptable?
      return redirect_to workspace_invite_path(params[:token]), alert: t("workspace_invites.accept.unavailable")
    end

    @user = User.new(invite_signup_params)

    unless @workspace_invite.acceptable_for?(@user)
      @user.errors.add(:email_address, t(".email_mismatch"))
      return render :show, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @user.save!
      @workspace_invite.accept!(@user)
      @user.update!(active_workspace: @workspace_invite.workspace)
    end

    start_new_session_for(@user)
    redirect_to root_path, notice: t(".created", workspace: @workspace_invite.workspace.name)
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
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

    def invite_signup_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end

    def prepare_invite_signup
      @user ||= User.new(email_address: @workspace_invite.email_address)
      session[:return_to_after_authenticating] = workspace_invite_url(@workspace_invite.token) unless authenticated?
    end
end
