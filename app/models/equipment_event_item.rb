class EquipmentEventItem < ApplicationRecord
  belongs_to :equipment_event
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :equipment_event_id }
end
