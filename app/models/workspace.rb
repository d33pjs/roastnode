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
  has_one_attached :logo
  has_one_attached :banner

  normalizes :default_currency, with: ->(currency) { currency.strip.upcase }

  validates :name, presence: true
  validates :default_currency, presence: true

  def destroy_with_history!
    transaction do
      User.where(active_workspace_id: id).update_all(active_workspace_id: nil)
      beans.find_each(&:destroy_with_history!)
      equipment.find_each(&:destroy_with_history!)
      preparation_tools.find_each(&:destroy_with_history!)
      equipment_events.destroy_all
      inventory_adjustments.destroy_all
      brews.destroy_all
      destroy!
    end
  end
end
