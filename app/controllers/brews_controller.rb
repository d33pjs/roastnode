class BrewsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update taste serving destroy]
  before_action :set_brew, only: %i[show edit update taste serving destroy]
  before_action :set_recipe_guide, only: %i[new create]
  before_action :set_selected_method, only: %i[new create]
  before_action :set_serving_suggestions, only: %i[new create edit update show serving]

  def index
    @brew_history_view = params[:view] == "hero" ? "hero" : "compact"
    @coffee_filter = params[:filter].presence_in(%w[all brews external]) || "all"
    @brew_history = HistoryPaginator.new(coffee_history_scope, page: params[:page])
  end

  def show
  end

  def edit
    @selected_method = @brew.method
    load_form_options(
      selected_bean: @brew.bean,
      selected_grinder: @brew.grinder,
      selected_machine: @brew.machine,
      selected_brewer: @brew.brewer,
      allow_archived_equipment: true
    )
    @selected_preparation_tools = @brew.preparation_tools.to_a
    @autofocus_field = nil
    @draft_storage_key = nil
    @hidden_brew_fields = []
    prepare_record_links(@brew)
  end

  def new
    @repeat_source_brew = repeat_source_brew_from_params
    if @repeat_source_brew
      @selected_method = @repeat_source_brew.method
      if disabled_brew_method?(@selected_method)
        return redirect_to new_brew_path,
          alert: t(".repeat_method_disabled", method: t("brews.methods.#{@selected_method}"))
      end
    end
    load_form_options
    default_attributes = default_brew_attributes(method: @selected_method)

    unless default_attributes[:bean]
      if @repeat_source_brew
        return redirect_to new_brew_path, alert: t(".repeat_source_unavailable")
      end

      return redirect_to new_bean_path, alert: t(".needs_bean")
    end

    if @selected_method == "quick_drip" && @brewers.empty?
      return redirect_to new_equipment_path(kind: "brewer"), alert: t(".needs_brewer")
    end

    @brew = current_workspace.brews.new(default_attributes.merge(method: @selected_method))
    @brew.recipe = @recipe if @recipe
    prepare_record_links(@brew)
    set_brew_form_preferences
    @draft_storage_key = @repeat_source_brew ? repeat_brew_draft_storage_key(@repeat_source_brew) : brew_draft_storage_key
  end

  def create
    if @disabled_requested_method.present?
      return redirect_to new_brew_path, alert: t(".method_disabled", method: t("brews.methods.#{@disabled_requested_method}"))
    end

    attributes = brew_params
    scope_brew_reference_ids!(attributes)
    resolve_recipient_attributes!(attributes)
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    attributes[:method] = @selected_method
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)
    @brew = current_workspace.brews.new(attributes)
    @brew.user = Current.user
    load_form_options(selected_bean: @brew.bean, selected_grinder: @brew.grinder, selected_machine: @brew.machine, selected_brewer: @brew.brewer)
    set_brew_form_preferences
    @draft_storage_key = brew_draft_storage_key
    apply_recipe_snapshot

    bean = @brew.bean
    previous_status = bean&.bag_status
    created = with_workspace_activity(
      action: "brew.created", subject: -> { @brew }, occurred_at: -> { @brew.occurred_at }
    ) do
      saved = save_brew_with_preparation_tools
      if saved
        refresh_public_shares_for(@brew, comparisons: true)
        record_used_up_transition!(bean, previous_status:) if bean
      end
      saved
    end

    if created
      redirect_to @brew, notice: t(".created")
    else
      prepare_record_links(@brew)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @selected_method = @brew.method
    @hidden_brew_fields = []
    attributes = brew_params
    scope_brew_reference_ids!(attributes, existing_brew: @brew)
    resolve_recipient_attributes!(attributes, existing_brew: @brew)
    attributes[:method] = @brew.method
    preparation_tool_ids = Array(attributes.delete(:preparation_tool_ids)).reject(&:blank?)
    @selected_preparation_tools = preparation_tools_from_ids(preparation_tool_ids)

    ActiveRecord::Base.transaction do
      target_bean_id = attributes[:bean_id].presence || @brew.bean_id
      target_bean = current_workspace.beans.find(target_bean_id)
      previous_status = target_bean.bag_status
      @brew.update_with_inventory_correction!(attributes, preparation_tools: @selected_preparation_tools)
      refresh_public_shares_for(@brew, comparisons: comparison_inputs_changed?(@brew))
      Activity::Emitter.record!(
        action: "brew.updated", workspace: current_workspace, actor: Current.user, subject: @brew
      )
      record_used_up_transition!(target_bean, previous_status:)
    end
    redirect_to @brew, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    load_form_options(
      selected_bean: @brew.bean,
      selected_grinder: @brew.grinder,
      selected_machine: @brew.machine,
      selected_brewer: @brew.brewer,
      allow_archived_equipment: true
    )
    prepare_record_links(@brew)
    render :edit, status: :unprocessable_entity
  end

  def taste
    updated = with_workspace_activity(action: "brew.taste_changed", subject: @brew) do
      saved = @brew.update(taste_brew_params)
      refresh_public_shares_for(@brew, comparisons: comparison_inputs_changed?(@brew)) if saved
      saved
    end

    if updated
      redirect_to @brew, notice: t(".updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def serving
    attributes = serving_brew_params
    resolve_recipient_attributes!(attributes, existing_brew: @brew)
    updated = with_workspace_activity(action: "brew.serving_changed", subject: @brew) do
      if @brew.update(attributes)
        refresh_public_shares_for(@brew)
        true
      else
        false
      end
    end

    if updated
      redirect_to @brew, notice: t(".updated")
    else
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    @brew.reload
    flash.now[:alert] = t(".failed")
    render :show, status: :unprocessable_entity
  end

  def destroy
    _subject_label = Activity::Metadata.subject_label(@brew)
    ActiveRecord::Base.transaction do
      @brew.destroy_with_inventory_reversal!
      PublicBeanShareRefresher.refresh_comparisons_for(@brew)
      Activity::Emitter.record!(
        action: "brew.deleted", workspace: current_workspace, actor: Current.user, subject: @brew, details: {}
      )
    end
    redirect_to root_path, notice: t(".destroyed")
  end

  private
    DECIMAL_BREW_FIELDS = %i[
      bean_weight_grams
      ground_weight_grams
      dose_grams
      beverage_grams
      brew_temperature_celsius
      machine_cups
      coffee_spoons
      grams_per_coffee_spoon
    ].freeze

    def set_brew
      @brew = current_workspace.brews.includes(
        :grinder, :machine, :brewer, :public_brew_share,
        primary_photo_record: :blob,
        photos_attachments: :blob,
        bean: [ { primary_photo_record: :blob }, { photos_attachments: :blob } ],
        user: { avatar_attachment: :blob },
        recipient_user: { avatar_attachment: :blob },
        brew_preparation_tools: :preparation_tool
      ).find(params[:id])
    end

    def set_serving_suggestions
      @recipient_users = current_workspace.users.with_attached_avatar.order(:display_name, :email_address).to_a
      @recipient_name_suggestions = current_workspace.brews
        .where(recipient_kind: "guest").where.not(recipient_name: [ nil, "" ])
        .distinct.order(:recipient_name).pluck(:recipient_name)
      @cup_style_suggestions = (
        ExternalCoffee::DRINK_TYPE_SUGGESTIONS +
          current_workspace.brews.where.not(cup_style: [ nil, "" ]).distinct.order(:cup_style).pluck(:cup_style)
      ).uniq
    end

    def set_recipe_guide
      recipe_id = params[:recipe_id].presence || params.dig(:brew, :recipe_id).presence
      return if recipe_id.blank?

      @recipe = current_workspace.recipes.find(recipe_id)
    end

    def set_selected_method
      @disabled_requested_method = nil

      if @recipe
        @selected_method = @recipe.method.presence_in(Brew::BREW_METHODS) || "espresso"
        return
      end

      requested = params[:method].presence || params.dig(:brew, :method).presence
      if requested.present? && Brew::BREW_METHODS.include?(requested) && disabled_brew_method?(requested)
        @disabled_requested_method = requested
      end
      @selected_method = requested.presence_in(Current.user.enabled_brew_methods) || default_log_method
    end

    def disabled_brew_method?(method)
      Current.user.enabled_brew_methods.exclude?(method)
    end

    def default_log_method
      last_method = current_workspace
        .brews
        .where(user: Current.user, method: Current.user.enabled_brew_methods)
        .order(occurred_at: :desc, created_at: :desc)
        .pick(:method)

      last_method.presence || Current.user.enabled_brew_methods.first
    end

    def coffee_history_scope
      case @coffee_filter
      when "brews"
        brew_history_scope
      when "external"
        external_coffee_history_scope
      else
        (brew_history_scope.to_a + external_coffee_history_scope.to_a)
          .sort_by { |record| [ record.occurred_at || Time.at(0), record.created_at || Time.at(0) ] }
          .reverse
      end
    end

    def brew_history_scope
      current_workspace
        .brews
        .includes(
          :grinder, :machine, :brewer, :public_brew_share,
          primary_photo_record: :blob,
          photos_attachments: :blob,
          bean: [ { primary_photo_record: :blob }, { photos_attachments: :blob } ],
          user: { avatar_attachment: :blob },
          recipient_user: { avatar_attachment: :blob },
          brew_preparation_tools: :preparation_tool
        )
        .order(occurred_at: :desc, created_at: :desc)
    end

    def external_coffee_history_scope
      current_workspace
        .external_coffees
        .includes(:user, :primary_photo_record, photos_attachments: :blob)
        .order(occurred_at: :desc, created_at: :desc)
    end

    def load_form_options(selected_bean: nil, selected_grinder: nil, selected_machine: nil, selected_brewer: nil, allow_archived_equipment: false)
      selected_bean = selected_workspace_record(selected_bean)
      selected_grinder = selected_equipment_record(selected_grinder, kind: :grinder, allow_archived: allow_archived_equipment)
      selected_machine = selected_equipment_record(selected_machine, kind: :machine, allow_archived: allow_archived_equipment)
      selected_brewer = selected_equipment_record(selected_brewer, kind: :brewer, allow_archived: allow_archived_equipment)

      @beans = current_workspace.beans.open.includes(:primary_photo_record, photos_attachments: :blob).to_a
      @beans << selected_bean if selected_bean && @beans.exclude?(selected_bean)
      sort_beans_for_method!
      @grinders = equipment_options(kind: :grinder, selected_equipment: selected_grinder, allow_archived: allow_archived_equipment)
      @machines = equipment_options(kind: :machine, selected_equipment: selected_machine, allow_archived: allow_archived_equipment)
      @brewers = equipment_options(kind: :brewer, selected_equipment: selected_brewer, allow_archived: allow_archived_equipment)
      @preparation_tools = current_workspace.preparation_tools.active.where(brew_method: @selected_method || "espresso").ordered.includes(:primary_photo_record, photos_attachments: :blob)
    end

    def sort_beans_for_method!
      @beans.sort_by! do |bean|
        [
          quick_drip_bean_priority(bean),
          bean.opened_on || Date.new(9999, 12, 31),
          bean.created_at,
          bean.name
        ]
      end
    end

    def quick_drip_bean_priority(bean)
      return 0 unless @selected_method == "quick_drip"

      case bean.roast_type
      when "filter"
        0
      when "omni"
        1
      else
        2
      end
    end

    def default_brew_attributes(method:)
      return repeat_brew_attributes(@repeat_source_brew) if @repeat_source_brew
      return default_quick_drip_attributes if method == "quick_drip"

      default_espresso_attributes
    end

    def default_espresso_attributes
      last_brew = last_brew_for_defaults(method: "espresso")
      bean = default_brew_bean(last_brew)
      return { bean: nil } unless bean

      @selected_preparation_tools = default_preparation_tools(last_brew, method: "espresso")
      machine = default_equipment(last_brew&.machine)
      attributes = {
        bean:,
        occurred_at: Time.current,
        machine:
      }

      return attributes unless last_brew

      attributes.merge(
        grinder: default_equipment(last_brew.grinder),
        grind_setting: last_brew.grind_setting,
        brew_temperature_celsius: last_brew.brew_temperature_celsius,
        preinfusion_seconds: machine&.preinfusion_enabled? ? last_brew.preinfusion_seconds : nil,
        low_flow_start_seconds: machine&.low_flow_start_enabled? ? last_brew.low_flow_start_seconds : nil
      )
    end

    def default_quick_drip_attributes
      last_brew = last_brew_for_defaults(method: "quick_drip")
      bean = default_quick_drip_bean(last_brew)
      return { bean: nil } unless bean
      return { bean:, brewer: nil } if @brewers.empty?

      @selected_preparation_tools = default_preparation_tools(last_brew, method: "quick_drip")
      {
        bean:,
        brewer: default_brewer(last_brew),
        grinder: bean.pre_ground? ? nil : default_equipment(last_brew&.grinder),
        occurred_at: Time.current,
        machine_cups: last_brew&.machine_cups,
        coffee_spoons: last_brew&.coffee_spoons,
        grind_setting: last_brew&.grind_setting
      }
    end

    def repeat_source_brew_from_params
      repeat_brew_id = params[:repeat_brew_id].presence
      return if repeat_brew_id.blank?

      current_workspace.brews.includes(:bean, :grinder, :machine, :brewer, :preparation_tools).find(repeat_brew_id)
    end

    def repeat_brew_attributes(source_brew)
      return repeat_quick_drip_attributes(source_brew) if source_brew.quick_drip?

      repeat_espresso_attributes(source_brew)
    end

    def repeat_espresso_attributes(source_brew)
      bean = repeat_brew_bean(source_brew.bean)
      return { bean: nil } unless bean

      @repeat_target_bean = bean
      @selected_preparation_tools = default_preparation_tools(source_brew, method: source_brew.method)
      machine = default_equipment(source_brew.machine)
      {
        bean:,
        occurred_at: Time.current,
        grinder: default_equipment(source_brew.grinder),
        machine:,
        bean_weight_grams: source_brew.bean_weight_grams,
        ground_weight_grams: source_brew.ground_weight_grams,
        dose_grams: source_brew.dose_grams,
        beverage_grams: source_brew.beverage_grams,
        grind_setting: source_brew.grind_setting,
        brew_temperature_celsius: source_brew.brew_temperature_celsius,
        total_time_seconds: source_brew.total_time_seconds,
        preinfusion_seconds: machine&.preinfusion_enabled? ? source_brew.preinfusion_seconds : nil,
        low_flow_start_seconds: machine&.low_flow_start_enabled? ? source_brew.low_flow_start_seconds : nil,
        first_drip_seconds: source_brew.first_drip_seconds
      }
    end

    def repeat_quick_drip_attributes(source_brew)
      bean = repeat_brew_bean(source_brew.bean)
      return { bean: nil } unless bean

      @repeat_target_bean = bean
      @selected_preparation_tools = default_preparation_tools(source_brew, method: source_brew.method)
      attributes = {
        bean:,
        occurred_at: Time.current,
        brewer: default_equipment(source_brew.brewer),
        grinder: bean.pre_ground? ? nil : default_equipment(source_brew.grinder),
        machine_cups: source_brew.machine_cups,
        coffee_spoons: source_brew.coffee_spoons,
        grams_per_coffee_spoon: source_brew.grams_per_coffee_spoon,
        beverage_grams: source_brew.beverage_grams,
        total_time_seconds: source_brew.total_time_seconds,
        grind_setting: source_brew.grind_setting
      }
      attributes[:bean_weight_grams] = source_brew.bean_weight_grams unless source_brew.coffee_amount_estimated_spoons?
      attributes
    end

    def repeat_brew_bean(source_bean)
      return source_bean if source_bean&.open?

      repeat_bean_family(source_bean)
        .select(&:open?)
        .max_by { |bean| [ bean.opened_on || Date.new(0), bean.created_at || Time.zone.at(0) ] }
    end

    def repeat_bean_family(source_bean)
      return [] unless source_bean

      root = source_bean
      seen_ids = {}
      while root.duplicated_from_bean && !seen_ids[root.duplicated_from_bean_id]
        seen_ids[root.id] = true
        root = root.duplicated_from_bean
      end

      family = []
      frontier = [ root ]
      seen_ids = {}
      until frontier.empty?
        bean = frontier.shift
        next if bean.blank? || seen_ids[bean.id]

        seen_ids[bean.id] = true
        family << bean
        frontier.concat(current_workspace.beans.where(duplicated_from_bean_id: bean.id).to_a)
      end

      family
    end

    def brew_default_scope(scope, method:)
      scope.where(method:).includes(:bean, :grinder, :machine, :brewer, :preparation_tools).order(occurred_at: :desc, created_at: :desc)
    end

    def last_brew_for_defaults(method:)
      brew_default_scope(Current.user.brews.where(workspace: current_workspace), method:).first ||
        brew_default_scope(current_workspace.brews, method:).first
    end

    def default_brew_bean(last_brew)
      return last_brew.bean if last_brew&.bean&.open?

      @beans.first
    end

    def default_quick_drip_bean(last_brew)
      return last_brew.bean if last_brew&.bean&.open?

      @beans.find { |bean| bean.roast_type == "filter" } ||
        @beans.find { |bean| bean.roast_type == "omni" } ||
        @beans.first
    end

    def default_equipment(equipment)
      equipment if equipment&.workspace_id == current_workspace.id && !equipment.archived?
    end

    def default_brewer(last_brew)
      default_equipment(last_brew&.brewer) || (@brewers.one? ? @brewers.first : nil)
    end

    def equipment_options(kind:, selected_equipment: nil, allow_archived: false)
      selected_equipment = selected_equipment_record(selected_equipment, kind:, allow_archived:)
      options = current_workspace.equipment.active.public_send(kind).includes(:primary_photo_record, photos_attachments: :blob).order(:name).to_a
      options << selected_equipment if selected_equipment && options.exclude?(selected_equipment)
      options.sort_by(&:name)
    end

    def default_preparation_tools(last_brew, method:)
      return [] unless last_brew

      last_brew.preparation_tools.select do |tool|
        tool.workspace_id == current_workspace.id && tool.active? && tool.brew_method == method
      end
    end

    def preparation_tools_from_ids(ids)
      tools_by_id = current_workspace.preparation_tools.active.where(brew_method: @selected_method).where(id: ids).index_by(&:id)
      ids.map { |id| tools_by_id[id.to_i] }.compact
    end

    def selected_workspace_record(record)
      record if workspace_record?(record)
    end

    def selected_equipment_record(record, kind:, allow_archived: false)
      return unless workspace_record?(record)
      return unless record.public_send("#{kind}?")
      return if record.archived? && !allow_archived

      record
    end

    def workspace_record?(record)
      record.present? && record.respond_to?(:workspace_id) && record.workspace_id == current_workspace.id
    end

    def scope_brew_reference_ids!(attributes, existing_brew: nil)
      scope_bean_reference_id!(attributes, existing_brew:)
      scope_equipment_reference_id!(attributes, :grinder_id, :grinder, existing_equipment: existing_brew&.grinder)
      scope_equipment_reference_id!(attributes, :machine_id, :machine, existing_equipment: existing_brew&.machine)
      scope_equipment_reference_id!(attributes, :brewer_id, :brewer, existing_equipment: existing_brew&.brewer)
    end

    def scope_bean_reference_id!(attributes, existing_brew:)
      return unless attributes.key?(:bean_id) && attributes[:bean_id].present?
      return if existing_brew && attributes[:bean_id].to_s == existing_brew.bean_id.to_s

      attributes[:bean_id] = nil unless current_workspace.beans.open.exists?(id: attributes[:bean_id])
    end

    def scope_equipment_reference_id!(attributes, key, kind, existing_equipment: nil)
      return unless attributes.key?(key) && attributes[key].present?
      return if historical_equipment_reference?(attributes[key], existing_equipment, kind)

      attributes[key] = nil unless current_workspace.equipment.active.public_send(kind).exists?(id: attributes[key])
    end

    def historical_equipment_reference?(id, equipment, kind)
      return false unless equipment
      return false unless equipment.id.to_s == id.to_s

      selected_equipment_record(equipment, kind:, allow_archived: true).present?
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
        :method,
        :bean_id,
        :grinder_id,
        :machine_id,
        :brewer_id,
        :occurred_at,
        :bean_weight_grams,
        :ground_weight_grams,
        :dose_grams,
        :beverage_grams,
        :machine_cups,
        :coffee_spoons,
        :grams_per_coffee_spoon,
        :grind_setting,
        :brew_temperature_celsius,
        :total_time_seconds,
        :preinfusion_seconds,
        :low_flow_start_seconds,
        :first_drip_seconds,
        :channeling,
        :flow_control_used,
        :taste_balance,
        :rating,
        :recipient_selection,
        :recipient_name,
        :cup_style,
        :notes,
        :public_note,
        {
          preparation_tool_ids: [],
          photos: [],
          record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
        }
      ]), *DECIMAL_BREW_FIELDS)
    end

    def apply_recipe_snapshot
      return unless @recipe

      @brew.recipe = @recipe
      @brew.recipe_snapshot = @recipe.profile.deep_dup
    end

    def taste_brew_params
      params.expect(brew: [ :taste_balance, :rating ])
    end

    def serving_brew_params
      params.expect(brew: [ :recipient_selection, :recipient_name, :cup_style ])
    end

    def resolve_recipient_attributes!(attributes, existing_brew: nil)
      selection = attributes.delete(:recipient_selection).presence || "self"
      name = attributes[:recipient_name].to_s.strip.presence
      previous_recipient_name = existing_brew&.recipient_guest? ? existing_brew.recipient_name.to_s.strip.presence : nil
      selection = "guest" if selection == "self" && name.present? && name != previous_recipient_name
      attributes[:recipient_selection] = selection

      case selection
      when "self"
        attributes.merge!(recipient_kind: "self", recipient_user: nil, recipient_name: nil)
      when "guest"
        attributes.merge!(recipient_kind: "guest", recipient_user: nil, recipient_name: name)
      when /\Amember:(\d+)\z/
        attributes.merge!(
          recipient_kind: "household_member",
          recipient_user: current_workspace.users.find(Regexp.last_match(1)),
          recipient_name: nil
        )
      when "existing_recipient"
        raise ActiveRecord::RecordNotFound unless existing_brew&.recipient_household_member?

        attributes.merge!(
          recipient_kind: "household_member",
          recipient_user: existing_brew.recipient_user,
          recipient_name: nil
        )
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def refresh_public_shares_for(record, comparisons: false)
      PublicBrewShareRefresher.refresh_for(record)
      if comparisons
        PublicBeanShareRefresher.refresh_comparisons_for(record)
      else
        PublicBeanShareRefresher.refresh_for(record)
      end
    end

    def comparison_inputs_changed?(brew)
      brew.saved_change_to_bean_id? ||
        brew.saved_change_to_method? ||
        brew.saved_change_to_rating? ||
        (brew.espresso? && brew.saved_change_to_channeling?)
    end

    def set_brew_form_preferences
      if @selected_method == "espresso"
        @autofocus_field = Current.user.default_brew_focus_field
        @hidden_brew_fields = Current.user.hidden_brew_field_names
      else
        @autofocus_field = nil
        @hidden_brew_fields = []
      end
    end

    def brew_draft_storage_key
      "roastnode:brew:new:#{@selected_method}:#{current_workspace.id}:#{Current.user.id}"
    end

    def repeat_brew_draft_storage_key(source_brew)
      "roastnode:brew:repeat:#{source_brew.method}:#{current_workspace.id}:#{Current.user.id}:#{source_brew.id}"
    end
end
