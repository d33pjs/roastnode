class ProfilesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to root_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:display_name)
    end
end
