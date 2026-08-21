module Activity
  module Metadata
    MAX_TEXT = 160
    MAX_ARRAY = 10
    SENSITIVE = %r{[a-z][a-z0-9+.-]*://|rails/active_storage|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}|(?:password|digest|token|secret|session|signed_id|attachment|filename|ip_address|file_path|error)\s*[:=]}i
    ABSOLUTE_PATH = %r{\A(?:/|\.\./|[a-z]:[\\/]|\\\\)}i

    module_function

    def build(action:, actor:, subject:, details: {})
      definition = EventContract.fetch(action)
      details = details.to_h.stringify_keys
      unexpected = details.keys - definition.fetch(:detail_keys)
      raise ArgumentError, "unsupported activity details: #{unexpected.join(', ')}" if unexpected.any?
      definition.fetch(:detail_values).each do |key, allowed|
        next unless details.key?(key)
        raise ArgumentError, "unsupported #{key} for #{action}" unless allowed.include?(details.fetch(key).to_s)
      end

      automatic_details = auto_details(subject).slice(*definition.fetch(:automatic_metadata_keys))

      actor_payload(actor)
        .merge(subject_payload(subject))
        .merge(automatic_details.transform_values { |value| safe_value(value) })
        .merge(details.transform_values { |value| safe_value(value) })
        .compact
    end

    def actor_payload(actor)
      return { "actor_kind" => "system", "actor_label" => "System" } unless actor

      { "actor_kind" => "user", "actor_label" => safe_text(actor.display_label) }
    end

    def subject_payload(subject)
      return {} unless subject

      { "record_kind" => subject.class.model_name.singular, "subject_label" => safe_text(subject_label(subject)) }
    end

    def subject_label(subject)
      case subject
      when Brew
        "#{subject.method == "quick_drip" ? "Quick Drip" : "Espresso"} with #{subject.bean&.name || "deleted bean"}"
      when Bean then subject.display_name
      when ExternalCoffee then subject.drink_type
      when Equipment, PreparationTool then subject.name
      when EquipmentEvent then subject.event_type_summary
      when InventoryAdjustment then subject.bean&.display_name || "Inventory adjustment"
      when Recipe then subject.title
      when PublicBrewShare, PublicBeanShare, PublicRecipeShare then subject.title.presence || subject.class.model_name.human
      when Workspace then subject.name
      when WorkspaceInvite then "#{subject.role.to_s.humanize} invite"
      when HouseholdInvite then "Household invite"
      when Membership then subject.user&.display_label || "Former member"
      when DataImport then "#{subject.source.to_s.humanize} import"
      when User then subject.display_label
      when InstanceBackupProfile then subject.name
      when InstanceBackupRun then subject.instance_backup_profile&.name || "Instance backup"
      when PasskeyCredential then "Passkey"
      else subject.class.model_name.human
      end
    end

    def auto_details(subject)
      case subject
      when Brew then { "method" => subject.method }
      when Bean then { "status" => subject.bag_status }
      when InventoryAdjustment then { "amount_grams" => subject.delta_grams&.to_s("F") }
      when EquipmentEvent
        { "event_types" => subject.event_type_names.first(MAX_ARRAY), "equipment_labels" => subject.equipment.map(&:name).sort.first(MAX_ARRAY) }
      when PublicBrewShare, PublicBeanShare, PublicRecipeShare then { "enabled" => subject.enabled? }
      when WorkspaceInvite, Membership then { "role" => subject.role }
      when DataImport then { "source" => subject.source }
      when InstanceBackupProfile then { "backup_kind" => subject.backup_kind }
      when InstanceBackupRun
        { "backup_kind" => subject.backup_kind, "status" => subject.status, "file_size_bytes" => subject.file_size_bytes }
      else {}
      end
    end

    def safe_value(value)
      case value
      when String, Symbol then safe_text(value)
      when Numeric, TrueClass, FalseClass, NilClass then value
      when Array then value.first(MAX_ARRAY).map { |item| safe_text(item) }
      else raise ArgumentError, "activity metadata must be flat JSON scalars"
      end
    end

    def safe_text(value)
      text = value.to_s.strip.squish
      return "[redacted]" if unsafe_text?(text)

      text.first(MAX_TEXT).presence || "Unknown"
    end

    def unsafe_text?(value)
      text = value.to_s.strip.squish
      text.match?(SENSITIVE) || text.match?(ABSOLUTE_PATH)
    end
  end
end
