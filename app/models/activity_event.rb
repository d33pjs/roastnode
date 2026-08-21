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

      allowed = %w[actor_kind actor_label record_kind subject_label] + definition.fetch(:metadata_keys)
      errors.add(:metadata, "contains unsupported keys") if metadata.keys.map(&:to_s).difference(allowed).any?
      errors.add(:metadata, "is too large") if metadata.to_json.bytesize > 2.kilobytes
      errors.add(:metadata, "has an invalid actor kind") unless %w[user system].include?(metadata["actor_kind"])
      metadata.each_value do |value|
        valid_value = value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil? ||
          (value.is_a?(Array) && value.all? { |item| item.is_a?(String) })
        errors.add(:metadata, "must stay flat") unless valid_value
        text_values = value.is_a?(Array) ? value : [ value ]
        if text_values.any? { |item| item.is_a?(String) && Activity::Metadata.unsafe_text?(item) }
          errors.add(:metadata, "contains unsafe text")
        end
        if text_values.any? { |item| item.is_a?(String) && item.length > Activity::Metadata::MAX_TEXT }
          errors.add(:metadata, "contains overlong text")
        end
        errors.add(:metadata, "contains too many values") if value.is_a?(Array) && value.length > Activity::Metadata::MAX_ARRAY
      end
      definition.fetch(:detail_values).each do |key, values|
        errors.add(:metadata, "contains an unsupported #{key}") if metadata.key?(key) && !values.include?(metadata[key].to_s)
      end
    rescue KeyError
      errors.add(:action, "is not supported")
    end

    def validate_activity_subject_contract(definition)
      unless subject.class.base_class.name == definition.fetch(:subject_type)
        errors.add(:subject, "type does not match action")
        return
      end

      subject_workspace_id = if subject.is_a?(Workspace)
        subject.id
      elsif subject.respond_to?(:workspace_id)
        subject.workspace_id
      end
      if workspace_id.present? && subject_workspace_id.present? && subject_workspace_id != workspace_id
        errors.add(:subject, "belongs to another workspace")
      elsif workspace_id.blank? && subject_workspace_id.present? && !subject.is_a?(Workspace)
        errors.add(:subject, "cannot be workspace-scoped for instance activity")
      end
    end
end
