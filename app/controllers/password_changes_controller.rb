class PasswordChangesController < ApplicationController
  before_action :set_user

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

    def password_change_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
end
