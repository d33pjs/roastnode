class BrewsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update taste destroy]
  before_action :set_brew, only: %i[show edit update taste destroy]

  def index
    @brew_history_view = params[:view] == "hero" ? "hero" : "compact"
    brews = current_workspace
      .brews
      .includes(:bean, :user, :grinder, :machine, brew_preparation_tools: :preparation_tool)
      .order(occurred_at: :desc, created_at: :desc)
    @brew_history = HistoryPaginator.new(brews, page: params[:page])
  end

  def show
  end

  def edit
    load_form_options(selected_bean: @brew.bean, selected_grinder: @brew.grinder, selected_machine: @brew.machine)
    @selected_preparation_tools = @brew.preparation_tools.to_a
    @autofocus_field = nil
    @draft_storage_key = nil
    @hidden_brew_fields = []
    prepare_record_links(@brew)
  end

  def new
    load_form_options
    default_attributes = default_brew_attributes

    unless default_attributes[:bean]
      return redirect_to new_bean_path, alert: t(".needs_bean")
    end

    @brew = current_workspace.brews.new(default_attributes)
    prepare_record_links(@brew)
    @autofocus_field = Current.user.default_brew_focus_field
    @draft_storage_key = brew_draft_storage_key
    @hidden_brew_fields = Current.user.hidden_brew_field_names
  end

  def create
    load_form_options
    @autofocus_field = Current.user.default_brew_focus_field
    @draft_storage_key = brew_draft_storage_key
    @hidden_brew_fields = Current.user.hidden_brew_field_names
    attributes = brew_params
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)
    @brew = current_workspace.brews.new(attributes)
    @brew.user = Current.user

    if save_brew_with_preparation_tools
      redirect_to @brew, notice: t(".created")
    else
      prepare_record_links(@brew)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    load_form_options(selected_bean: @brew.bean)
    @hidden_brew_fields = []
    attributes = brew_params
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)

    @brew.update_with_inventory_correction!(attributes, preparation_tools: @selected_preparation_tools)
    redirect_to @brew, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    prepare_record_links(@brew)
    render :edit, status: :unprocessable_entity
  end

  def taste
    if @brew.update(taste_brew_params)
      redirect_to @brew, notice: t(".updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @brew.destroy_with_inventory_reversal!
    redirect_to root_path, notice: t(".destroyed")
  end

  private
    DECIMAL_BREW_FIELDS = %i[
      bean_weight_grams
      ground_weight_grams
      dose_grams
      beverage_grams
      brew_temperature_celsius
    ].freeze

    def set_brew
      @brew = current_workspace.brews.includes(:bean, :grinder, :machine, :user, brew_preparation_tools: :preparation_tool).find(params[:id])
    end

    def load_form_options(selected_bean: nil, selected_grinder: nil, selected_machine: nil)
      @beans = current_workspace.beans.open.includes(:primary_photo_record, photos_attachments: :blob).to_a
      @beans << selected_bean if selected_bean && @beans.exclude?(selected_bean)
      @beans.sort_by! { |bean| [ bean.opened_on || Date.new(9999, 12, 31), bean.created_at, bean.name ] }
      @grinders = equipment_options(kind: :grinder, selected_equipment: selected_grinder)
      @machines = equipment_options(kind: :machine, selected_equipment: selected_machine)
      @preparation_tools = current_workspace.preparation_tools.active.espresso.ordered.includes(:primary_photo_record, photos_attachments: :blob)
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
      brew_default_scope(Current.user.brews.where(workspace: current_workspace)).first ||
        brew_default_scope(current_workspace.brews).first
    end

    def brew_default_scope(scope)
      scope.includes(:bean, :grinder, :machine, :preparation_tools).order(occurred_at: :desc, created_at: :desc)
    end

    def default_brew_bean(last_brew)
      return last_brew.bean if last_brew&.bean&.open?

      @beans.first
    end

    def default_equipment(equipment)
      equipment if equipment&.workspace_id == current_workspace.id && !equipment.archived?
    end

    def equipment_options(kind:, selected_equipment: nil)
      options = current_workspace.equipment.active.public_send(kind).includes(:primary_photo_record, photos_attachments: :blob).order(:name).to_a
      options << selected_equipment if selected_equipment && options.exclude?(selected_equipment)
      options.sort_by(&:name)
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
      normalize_decimal_attributes(params.expect(brew: [
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
        :public_note,
        {
          preparation_tool_ids: [],
          photos: [],
          record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
        }
      ]), *DECIMAL_BREW_FIELDS)
    end

    def taste_brew_params
      params.expect(brew: [ :taste_balance, :rating ])
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def brew_draft_storage_key
      "roastnode:brew:new:#{current_workspace.id}:#{Current.user.id}"
    end
end
