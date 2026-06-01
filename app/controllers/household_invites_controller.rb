class HouseholdInvitesController < ApplicationController
  allow_unauthenticated_access only: %i[show signup]

  def show
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable?
      @household_invite = nil
      response.status = :not_found
    else
      prepare_invite_signup
    end
  end

  def accept
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable_for?(Current.user)
      return redirect_to household_invite_path(params[:token]), alert: t(".unavailable")
    end

    @workspace = Workspace.new(workspace_params)
    @household_invite.accept!(Current.user, workspace: @workspace)

    redirect_to root_path, notice: t(".accepted", workspace: @workspace.name)
  rescue ActiveRecord::RecordInvalid
    prepare_invite_signup
    render :show, status: :unprocessable_entity
  end

  def signup
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable?
      return redirect_to household_invite_path(params[:token]), alert: t("household_invites.accept.unavailable")
    end

    @user = User.new(invite_signup_params)
    @workspace = Workspace.new(workspace_params)

    unless @household_invite.acceptable_for?(@user)
      @user.errors.add(:email_address, t(".email_mismatch"))
      return render :show, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @user.save!
      @household_invite.accept!(@user, workspace: @workspace)
    end

    start_new_session_for(@user)
    redirect_to root_path, notice: t(".created", workspace: @workspace.name)
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private
    def invite_signup_params
      params.expect(user: [ :email_address, :display_name, :password, :password_confirmation ])
    end

    def workspace_params
      params.expect(workspace: [ :name ])
    end

    def prepare_invite_signup
      @user ||= User.new(email_address: @household_invite.email_address)
      @workspace ||= Workspace.new(kind: :household, default_currency: "EUR")
      session[:return_to_after_authenticating] = household_invite_url(@household_invite.token) unless authenticated?
    end
end
