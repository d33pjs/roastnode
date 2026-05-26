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

  validates :name, presence: true
  validates :default_currency, presence: true
end
