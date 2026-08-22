class ProfilesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    updated = with_account_activity(action: "profile.updated", user: @user) do
      next false unless @user.update(profile_params)

      PublicBrewShareRefresher.refresh_for(@user)
      PublicBeanShareRefresher.refresh_for(@user)
      @user
    end

    if updated
      redirect_to root_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      attributes = params.require(:user).permit(
        :display_name,
        :default_landing_screen,
        :theme,
        :number_format,
        :time_format,
        :time_zone,
        :default_brew_focus_field,
        :grams_per_coffee_spoon,
        :avatar,
        :public_banner,
        enabled_brew_methods: [],
        hidden_brew_field_names: []
      )

      normalize_decimal_attributes(attributes, :grams_per_coffee_spoon)
    end
end
