class Equipment < ApplicationRecord
  enum :kind, {
    grinder: "grinder",
    machine: "machine"
  }

  belongs_to :workspace

  has_many :grinder_brews, class_name: "Brew", foreign_key: :grinder_id, dependent: :nullify, inverse_of: :grinder
  has_many :machine_brews, class_name: "Brew", foreign_key: :machine_id, dependent: :nullify, inverse_of: :machine

  validates :name, presence: true
  validates :kind, presence: true
end
