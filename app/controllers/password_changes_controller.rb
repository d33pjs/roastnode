class PasswordChangesController < ApplicationController
  before_action :set_user
  rate_limit to: 10,
    within: 3.minutes,
    only: :update,
    by: :authenticated_password_check_rate_limit_key,
    with: -> {
      @user = Current.user
      @user.errors.add(:base, t(".rate_limited"))
      render :edit, status: :too_many_requests
    }

  def edit
  end

  def update
    unless @user.authenticate(password_change_params[:current_password].to_s)
      @user.errors.add(:current_password, t(".current_password_invalid"))
      return render :edit, status: :unprocessable_entity
    end

    if password_change_params[:password].blank?
      @user.errors.add(:password, :blank)
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password_change_params.except(:current_password))
      @user.sessions.destroy_all
      start_new_session_for(@user)
      redirect_to edit_profile_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user
      @user = Current.user
    end

    def authenticated_password_check_rate_limit_key
      "#{Current.user.id}:#{request.remote_ip}"
    end

    def password_change_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
end
