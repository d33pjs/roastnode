class EquipmentEvent < ApplicationRecord
  enum :event_type, {
    grinder_cleaning: "grinder_cleaning",
    grinder_deep_cleaning: "grinder_deep_cleaning",
    machine_descaling: "machine_descaling",
    machine_backflush: "machine_backflush",
    burr_change: "burr_change",
    other: "other"
  }

  belongs_to :workspace
  belongs_to :user

  has_many :equipment_event_items, dependent: :destroy
  has_many :equipment, through: :equipment_event_items

  before_validation :set_occurred_at

  validates :event_type, presence: true
  validate :affected_equipment_present
  validate :affected_equipment_belongs_to_workspace

  scope :recent, -> { order(occurred_at: :desc, created_at: :desc) }

  private
    def set_occurred_at
      self.occurred_at ||= Time.current
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
