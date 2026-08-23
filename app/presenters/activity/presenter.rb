module Activity
  class Presenter
    CATEGORY_ICON_CLASSES = {
      "coffee" => "bg-amber-100 text-amber-900",
      "beans_inventory" => "bg-emerald-100 text-emerald-900",
      "gear_maintenance" => "bg-slate-200 text-slate-900",
      "sharing_recipes" => "bg-sky-100 text-sky-900",
      "household_administration" => "bg-violet-100 text-violet-900",
      "system_security" => "bg-rose-100 text-rose-900"
    }.freeze
    NEUTRAL_ICON_CLASSES = "bg-rn-surface-muted text-rn-muted"

    def initialize(event, helpers:)
      @event = event
      @helpers = helpers
    end

    def summary
      return I18n.t("activity.events.unknown") unless definition

      variables = metadata.except("actor_label", "subject_label").symbolize_keys.merge(
        actor: actor_label,
        subject: metadata.fetch("subject_label", I18n.t("activity.events.deleted_subject"))
      )
      I18n.t("activity.events.#{definition.fetch(:summary)}", **variables)
    end

    def actor_label = metadata.fetch("actor_label", I18n.t("activity.events.system"))
    def timestamp = event.occurred_at
    def category_label = definition ? I18n.t("activity.categories.#{definition.fetch(:category)}") : I18n.t("activity.categories.unknown")
    def icon = definition && path ? definition.fetch(:icon) : "more_vert"
    def icon_container_classes = definition ? CATEGORY_ICON_CLASSES.fetch(definition.fetch(:category)) : NEUTRAL_ICON_CLASSES
    def restricted? = event.visibility != "workspace"

    def path
      return @path if defined?(@path)

      @path = resolve_path
    rescue ActiveRecord::RecordNotFound
      @path = nil
    end

    private
      attr_reader :event, :helpers

      def resolve_path
        return if EventContract::ACCOUNT_ACTIONS.include?(event.action)
        return unless definition && (subject = event.subject)

        case subject
        when Brew then helpers.brew_path(subject)
        when ExternalCoffee then helpers.external_coffee_path(subject)
        when Bean then helpers.bean_path(subject)
        when Equipment then helpers.equipment_path(subject)
        when PreparationTool then helpers.preparation_tool_path(subject)
        when EquipmentEvent then helpers.equipment_event_path(subject)
        when InventoryAdjustment then helpers.bean_path(subject.bean) if subject.bean
        when Recipe then helpers.recipe_path(subject)
        when PublicBrewShare then helpers.brew_path(subject.brew) if subject.brew
        when PublicBeanShare then helpers.bean_path(subject.bean) if subject.bean
        when PublicRecipeShare then helpers.recipe_path(subject.recipe) if subject.recipe
        when DataImport then helpers.beanconqueror_import_path(subject)
        end
      end

      def metadata = event.metadata.is_a?(Hash) ? event.metadata : {}

      def definition
        return @definition if defined?(@definition)

        candidate = EventContract.fetch(event.action)
        @definition = if candidate.fetch(:category) == event.category && presentation_contract_valid?(candidate)
          candidate
        end
      rescue KeyError
        @definition = nil
      end

      def presentation_contract_valid?(definition)
        return false unless event.metadata.is_a?(Hash)

        probe = ActivityEvent.new(
          workspace_id: event.workspace_id,
          category: event.category,
          action: event.action,
          occurred_at: event.occurred_at,
          visibility: event.visibility,
          metadata: event.metadata.deep_dup
        )
        probe.valid? && presentation_subject_valid?(definition)
      end

      def presentation_subject_valid?(definition)
        subject_type = event[:subject_type]
        subject_id = event[:subject_id]
        return false unless subject_type.present? == subject_id.present?
        return true if subject_type.blank?
        return false unless subject_type == definition.fetch(:subject_type)
        return true if EventContract::ACCOUNT_ACTIONS.include?(event.action)

        subject = event.subject
        return true unless subject
        return true if SubjectScope.compatible?(subject:, workspace: event.workspace)

        EventContract::ACCOUNT_ACTIONS.include?(event.action)
      rescue NameError, ActiveRecord::SubclassNotFound
        false
      end
  end
end
