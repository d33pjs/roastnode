class Equipment < ApplicationRecord
  enum :kind, {
    grinder: "grinder",
    machine: "machine"
  }

  belongs_to :workspace

  has_many :grinder_brews, class_name: "Brew", foreign_key: :grinder_id, dependent: :nullify, inverse_of: :grinder
  has_many :machine_brews, class_name: "Brew", foreign_key: :machine_id, dependent: :nullify, inverse_of: :machine
  has_many :equipment_event_items, dependent: :destroy
  has_many :equipment_events, through: :equipment_event_items

  validates :name, presence: true
  validates :kind, presence: true
end
