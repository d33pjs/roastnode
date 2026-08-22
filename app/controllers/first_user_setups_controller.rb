class FirstUserSetupsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_already_configured

  def new
    @user = User.new
  end

  def create
    @user = User.new(first_user_params.merge(instance_admin: true))

    created = User.transaction do
      next false unless @user.save

      Activity::Emitter.record!(
        action: "instance.first_user_created", workspace: nil, actor: @user, subject: @user
      )
      true
    end

    if created
      start_new_session_for(@user)
      redirect_to root_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def redirect_if_already_configured
      return if first_user_setup_available?

      redirect_to new_session_path, alert: t("first_user_setups.already_configured")
    end

    def first_user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
