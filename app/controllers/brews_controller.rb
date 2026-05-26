class BrewsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_brew, only: :show

  def show
  end

  def new
    load_form_options
    default_bean = default_brew_bean

    unless default_bean
      return redirect_to new_bean_path, alert: t(".needs_bean")
    end

    @brew = current_workspace.brews.new(bean: default_bean, occurred_at: Time.current)
  end

  def create
    load_form_options
    @brew = current_workspace.brews.new(brew_params)
    @brew.user = Current.user

    if @brew.save
      redirect_to @brew, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_brew
      @brew = current_workspace.brews.includes(:bean, :grinder, :machine, :user).find(params[:id])
    end

    def load_form_options
      @beans = current_workspace.beans.open
      @grinders = current_workspace.equipment.grinder.order(:name)
      @machines = current_workspace.equipment.machine.order(:name)
    end

    def default_brew_bean
      last_brew = Current.user.brews.where(workspace: current_workspace).includes(:bean).order(occurred_at: :desc, created_at: :desc).first
      return last_brew.bean if last_brew&.bean&.open?

      @beans.first
    end

    def brew_params
      params.expect(brew: [
        :bean_id,
        :grinder_id,
        :machine_id,
        :occurred_at,
        :bean_weight_grams,
        :ground_weight_grams,
        :dose_grams,
        :beverage_grams,
        :grind_setting,
        :brew_temperature_celsius,
        :total_time_seconds,
        :preinfusion_seconds,
        :first_drip_seconds,
        :channeling,
        :taste_balance,
        :rating,
        :notes
      ])
    end
end
