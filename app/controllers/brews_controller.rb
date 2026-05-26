class BrewsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update destroy]
  before_action :set_brew, only: %i[show edit update destroy]

  def show
  end

  def edit
    load_form_options(selected_bean: @brew.bean)
    @selected_preparation_tools = @brew.preparation_tools.to_a
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
    attributes = brew_params
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)
    @brew = current_workspace.brews.new(attributes)
    @brew.user = Current.user

    if save_brew_with_preparation_tools
      redirect_to @brew, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    load_form_options(selected_bean: @brew.bean)
    attributes = brew_params
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)

    @brew.update_with_inventory_correction!(attributes, preparation_tools: @selected_preparation_tools)
    redirect_to @brew, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @brew.destroy_with_inventory_reversal!
    redirect_to root_path, notice: t(".destroyed")
  end

  private
    def set_brew
      @brew = current_workspace.brews.includes(:bean, :grinder, :machine, :user).find(params[:id])
    end

    def load_form_options(selected_bean: nil)
      @beans = current_workspace.beans.open.to_a
      @beans << selected_bean if selected_bean && @beans.exclude?(selected_bean)
      @beans.sort_by! { |bean| [ bean.opened_on || Date.new(9999, 12, 31), bean.created_at, bean.name ] }
      @grinders = current_workspace.equipment.grinder.order(:name)
      @machines = current_workspace.equipment.machine.order(:name)
      @preparation_tools = current_workspace.preparation_tools.active.espresso.ordered
    end

    def default_brew_attributes
      last_brew = last_brew_for_defaults
      bean = default_brew_bean(last_brew)
      return { bean: nil } unless bean

      @selected_preparation_tools = default_preparation_tools(last_brew)
      attributes = {
        bean:,
        occurred_at: Time.current
      }

      return attributes unless last_brew

      attributes.merge(
        grinder: default_equipment(last_brew.grinder),
        machine: default_equipment(last_brew.machine),
        grind_setting: last_brew.grind_setting,
        brew_temperature_celsius: last_brew.brew_temperature_celsius,
        preinfusion_seconds: last_brew.preinfusion_seconds
      )
    end

    def last_brew_for_defaults
      Current.user.brews.where(workspace: current_workspace).includes(:bean, :grinder, :machine, :preparation_tools).order(occurred_at: :desc, created_at: :desc).first
    end

    def default_brew_bean(last_brew)
      return last_brew.bean if last_brew&.bean&.open?

      @beans.first
    end

    def default_equipment(equipment)
      equipment if equipment&.workspace_id == current_workspace.id
    end

    def default_preparation_tools(last_brew)
      return [] unless last_brew

      last_brew.preparation_tools.select do |tool|
        tool.workspace_id == current_workspace.id && tool.active? && tool.brew_method == "espresso"
      end
    end

    def preparation_tools_from_ids(ids)
      tools_by_id = current_workspace.preparation_tools.active.espresso.where(id: ids).index_by(&:id)
      ids.map { |id| tools_by_id[id.to_i] }.compact
    end

    def save_brew_with_preparation_tools
      Brew.transaction do
        @brew.save!
        @brew.snapshot_preparation_tools!(@selected_preparation_tools)
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
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
        :notes,
        { preparation_tool_ids: [], photos: [] }
      ])
    end
end
