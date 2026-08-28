require "ipaddr"

module Activity
  module Metadata
    MAX_TEXT = 160
    MAX_ARRAY = 10
    CONTROL_CHARACTERS = /\p{Cc}/.freeze
    SENSITIVE = %r{[a-z][a-z0-9+.-]*://|rails/active_storage|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}|(?:password|digest|token|secret|session|signed_id|attachment|filename|ip_address|file_path|error)\s*[:=]}i
    ABSOLUTE_PATH = %r{\A(?:/|\.\.[\\/]|[a-z]:[\\/]|\\\\)}i

    module_function

    def build(action:, actor:, actor_kind: nil, actor_label: nil, subject:, details: {})
      definition = EventContract.fetch(action)
      details = details.to_h.stringify_keys
      unexpected = details.keys - definition.fetch(:detail_keys)
      raise ArgumentError, "unsupported activity details: #{unexpected.join(', ')}" if unexpected.any?
      automatic_details = auto_details(subject).slice(*definition.fetch(:automatic_metadata_keys))

      normalized_details = details.to_h.stringify_keys.to_h do |key, value|
        [ key, normalize_value(value, definition.fetch(:metadata_schema).fetch(key)) ]
      end
      payload = actor_payload(actor, actor_kind:, actor_label:)
        .merge(subject_payload(subject))
        .merge(automatic_details.transform_values { |value| safe_value(value) })
        .merge(normalized_details.transform_values { |value| safe_value(value) })
        .compact
      validate_schema!(action:, payload:, schema: definition.fetch(:metadata_schema))
      payload
    end

    def actor_payload(actor, actor_kind:, actor_label:)
      return guest_actor_payload(actor, actor_label) if actor_kind == "guest"
      raise ArgumentError, "activity actor overrides are only permitted for guests" if actor_kind.present? || actor_label.present?

      return { "actor_kind" => "system", "actor_label" => "System" } unless actor

      { "actor_kind" => "user", "actor_label" => safe_text(actor.display_label) }
    end

    def guest_actor_payload(actor, actor_label)
      raise ArgumentError, "guest activity cannot have a user actor" if actor
      raise ArgumentError, "guest activity requires an actor label" if actor_label.blank?

      { "actor_kind" => "guest", "actor_label" => safe_text(actor_label) }
    end

    def subject_payload(subject)
      return {} unless subject

      { "record_kind" => subject.class.model_name.singular, "subject_label" => safe_text(subject_label(subject)) }
    end

    def subject_label(subject)
      case subject
      when Brew
        "#{subject.method == "quick_drip" ? "Quick Drip" : "Espresso"} with #{subject.bean&.name || "deleted bean"} for #{brew_recipient_label(subject)}"
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

    def brew_recipient_label(brew)
      return "me" if brew.recipient_self?
      return brew.recipient_user&.display_label || "a household member" if brew.recipient_household_member?

      brew.recipient_name.presence || "a guest"
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
      when Array
        unless value.all? { |item| item.is_a?(String) || item.is_a?(Symbol) }
          raise ArgumentError, "activity metadata arrays must contain only text"
        end

        value.first(MAX_ARRAY).map { |item| safe_text(item) }
      else raise ArgumentError, "activity metadata must be flat JSON scalars"
      end
    end

    def validate_schema!(action:, payload:, schema:)
      payload.each do |key, value|
        next if value_matches_schema?(value, schema.fetch(key))

        raise ArgumentError, "unsupported #{key} for #{action}"
      end
    end

    def value_matches_schema?(value, schema)
      type_matches = case schema.fetch(:type)
      when :string then value.is_a?(String)
      when :string_array then value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
      when :boolean then value == true || value == false
      when :integer then value.is_a?(Integer)
      when :decimal_string then value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?\z/)
      when :ip_address then canonical_ip_address?(value)
      else false
      end
      return false unless type_matches
      return false if schema[:minimum] && value < schema.fetch(:minimum)
      return false if schema[:maximum] && value > schema.fetch(:maximum)
      return true unless schema[:values]

      values = value.is_a?(Array) ? value : [ value ]
      values.all? { |item| schema.fetch(:values).include?(item) }
    end

    def normalize_value(value, schema)
      schema.fetch(:type) == :ip_address ? normalize_ip_address(value) : value
    end

    def normalize_ip_address(value)
      return value unless value.is_a?(String)

      IPAddr.new(value.strip).to_s
    rescue IPAddr::InvalidAddressError
      value
    end

    def canonical_ip_address?(value)
      value.is_a?(String) && IPAddr.new(value).to_s == value
    rescue IPAddr::InvalidAddressError
      false
    end

    def safe_text(value)
      text = value.to_s.strip.squish
      return "[redacted]" if unsafe_text?(text)

      text.first(MAX_TEXT).presence || "Unknown"
    end

    def unsafe_text?(value)
      raw_text = value.to_s
      return true if raw_text.match?(CONTROL_CHARACTERS)

      text = raw_text.strip.squish
      text.match?(SENSITIVE) || text.match?(ABSOLUTE_PATH)
    end
  end
end
