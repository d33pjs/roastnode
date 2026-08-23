class ActivityEvent < ApplicationRecord
  CATEGORIES = %w[
    coffee
    beans_inventory
    gear_maintenance
    sharing_recipes
    household_administration
    system_security
  ].freeze
  VISIBILITIES = %w[workspace workspace_admin instance_admin].freeze

  belongs_to :workspace, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :action, presence: true, inclusion: { in: Activity::EventContract.actions }
  validates :occurred_at, presence: true
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
  validate :metadata_is_a_hash
  validate :visibility_matches_workspace_scope
  validate :event_contract_matches

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end

  private
    def metadata_is_a_hash
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end

    def visibility_matches_workspace_scope
      if visibility == "instance_admin"
        errors.add(:workspace, "must be blank for instance activity") if workspace_id.present?
      elsif visibility.present?
        errors.add(:workspace, "must be present for workspace activity") if workspace_id.blank?
      end
    end

    def event_contract_matches
      return if action.blank?

      definition = Activity::EventContract.fetch(action)
      errors.add(:category, "does not match action") unless category == definition.fetch(:category)
      errors.add(:visibility, "is not permitted for action") unless definition.fetch(:visibilities).include?(visibility)
      validate_activity_subject_contract(definition) if subject
      return unless metadata.is_a?(Hash)

      allowed = definition.fetch(:metadata_schema).keys
      errors.add(:metadata, "contains unsupported keys") if metadata.keys.map(&:to_s).difference(allowed).any?
      missing_required_keys = definition.fetch(:required_metadata_keys).reject do |key|
        metadata.key?(key) && metadata[key].present?
      end
      errors.add(:metadata, "is missing required keys") if missing_required_keys.any?
      errors.add(:metadata, "is too large") if metadata.to_json.bytesize > 2.kilobytes
      actor_kind_schema = definition.fetch(:metadata_schema).fetch("actor_kind")
      unless Activity::Metadata.value_matches_schema?(metadata["actor_kind"], actor_kind_schema)
        errors.add(:metadata, "has an invalid actor kind")
      end
      metadata.each do |key, value|
        valid_value = value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil? ||
          (value.is_a?(Array) && value.all? { |item| item.is_a?(String) })
        errors.add(:metadata, "must stay flat") unless valid_value
        schema = definition.fetch(:metadata_schema)[key.to_s]
        unless schema && Activity::Metadata.value_matches_schema?(value, schema)
          errors.add(:metadata, "contains a value that does not match its action schema")
        end
        text_values = value.is_a?(Array) ? value : [ value ]
        if text_values.any? { |item| item.is_a?(String) && Activity::Metadata.unsafe_text?(item) }
          errors.add(:metadata, "contains unsafe text")
        end
        if text_values.any? { |item| item.is_a?(String) && item.length > Activity::Metadata::MAX_TEXT }
          errors.add(:metadata, "contains overlong text")
        end
        errors.add(:metadata, "contains too many values") if value.is_a?(Array) && value.length > Activity::Metadata::MAX_ARRAY
      end
    rescue KeyError
      errors.add(:action, "is not supported")
    end

    def validate_activity_subject_contract(definition)
      unless subject.class.base_class.name == definition.fetch(:subject_type)
        errors.add(:subject, "type does not match action")
        return
      end

      return if Activity::SubjectScope.compatible?(subject:, workspace:)

      message = workspace_id.present? ? "belongs to another workspace" : "cannot be workspace-scoped for instance activity"
      errors.add(:subject, message)
    end
end
