class BrewsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_brew, only: :show

  def show
  end

  def new
    load_form_options
    default_attributes = default_brew_attributes

    unless default_attributes[:bean]
      return redirect_to new_bean_path, alert: t(".needs_bean")
    end

    @brew = current_workspace.brews.new(default_attributes)
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

    def default_brew_attributes
      last_brew = last_brew_for_defaults
      bean = default_brew_bean(last_brew)
      return { bean: nil } unless bean

      attributes = {
        bean:,
        occurred_at: Time.current
      }

      return attributes unless last_brew

      attributes.merge(
        grinder: default_equipment(last_brew.grinder),
        machine: default_equipment(last_brew.machine),
        bean_weight_grams: last_brew.bean_weight_grams,
        ground_weight_grams: last_brew.ground_weight_grams,
        dose_grams: last_brew.dose_grams,
        beverage_grams: last_brew.beverage_grams,
        grind_setting: last_brew.grind_setting,
        brew_temperature_celsius: last_brew.brew_temperature_celsius,
        total_time_seconds: last_brew.total_time_seconds,
        preinfusion_seconds: last_brew.preinfusion_seconds,
        first_drip_seconds: last_brew.first_drip_seconds
      )
    end

    def last_brew_for_defaults
      Current.user.brews.where(workspace: current_workspace).includes(:bean, :grinder, :machine).order(occurred_at: :desc, created_at: :desc).first
    end

    def default_brew_bean(last_brew)
      return last_brew.bean if last_brew&.bean&.open?

      @beans.first
    end

    def default_equipment(equipment)
      equipment if equipment&.workspace_id == current_workspace.id
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
