class EquipmentEvent < ApplicationRecord
  include HasPrimaryPhoto

  enum :event_type, {
    grinder_cleaning: "grinder_cleaning",
    grinder_deep_cleaning: "grinder_deep_cleaning",
    machine_descaling: "machine_descaling",
    machine_backflush: "machine_backflush",
    brewer_cleaning: "brewer_cleaning",
    brewer_descaling: "brewer_descaling",
    filter_change: "filter_change",
    burr_change: "burr_change",
    other: "other"
  }

  belongs_to :workspace
  belongs_to :user

  has_many :equipment_event_items, dependent: :destroy
  has_many :equipment, through: :equipment_event_items
  has_many_attached :photos

  before_validation :normalize_event_types
  before_validation :set_occurred_at

  validates :event_type, presence: true
  validate :event_types_present
  validate :event_types_supported
  validate :affected_equipment_present
  validate :affected_equipment_belongs_to_workspace

  scope :recent, -> { order(occurred_at: :desc, created_at: :desc) }

  def event_type_names
    event_types.presence || [ event_type ].compact
  end

  def event_type_summary
    event_type_names.map { |name| event_type_label(name) }.to_sentence
  end

  def self.event_type_label(name)
    I18n.t("equipment_events.event_types.#{name}", default: name.to_s.humanize)
  end

  def event_type_label(name)
    self.class.event_type_label(name)
  end

  private
    def normalize_event_types
      selected_types = Array(event_types).reject(&:blank?).uniq
      selected_types = [ event_type ] if selected_types.empty? && event_type.present?

      self.event_types = selected_types
      self.event_type = selected_types.first if selected_types.any?
    end

    def set_occurred_at
      self.occurred_at ||= Time.current
    end

    def event_types_present
      errors.add(:event_types, "must include at least one type") if event_type_names.empty?
    end

    def event_types_supported
      event_type_names.each do |selected_type|
        errors.add(:event_types, "#{selected_type} is not supported") unless self.class.event_types.key?(selected_type)
      end
    end

    def affected_equipment_present
      errors.add(:equipment, "must include at least one item") if equipment.empty?
    end

    def affected_equipment_belongs_to_workspace
      return if workspace.blank?

      equipment.each do |item|
        errors.add(:equipment, "must belong to the workspace") if item.workspace_id != workspace_id
      end
    end
end
