class Workspace < ApplicationRecord
  enum :kind, {
    household: "household",
    roaster: "roaster",
    cafe: "cafe",
    community: "community"
  }

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :workspace_invites, dependent: :destroy
  has_many :data_imports, dependent: :destroy
  has_many :beans, dependent: :destroy
  has_many :equipment, dependent: :destroy
  has_many :brews, dependent: :destroy
  has_many :inventory_adjustments, dependent: :destroy
  has_many :equipment_events, dependent: :destroy
  has_many :preparation_tools, dependent: :destroy

  validates :name, presence: true
  validates :default_currency, presence: true
end
