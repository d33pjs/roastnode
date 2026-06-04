require "uri"

class Workspace < ApplicationRecord
  BUY_ME_A_COFFEE_HOSTS = %w[buymeacoffee.com www.buymeacoffee.com].freeze

  enum :kind, {
    household: "household",
    roaster: "roaster",
    cafe: "cafe",
    community: "community"
  }

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :workspace_invites, dependent: :destroy
  has_many :household_invites, dependent: :nullify
  has_many :data_imports, dependent: :destroy
  has_many :beans, dependent: :destroy
  has_many :equipment, dependent: :destroy
  has_many :brews, dependent: :destroy
  has_many :inventory_adjustments, dependent: :destroy
  has_many :equipment_events, dependent: :destroy
  has_many :preparation_tools, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :record_links, dependent: :destroy
  has_many :public_brew_shares, dependent: :destroy
  has_many :public_recipe_shares, dependent: :destroy
  has_one_attached :logo
  has_one_attached :banner

  normalizes :default_currency, with: ->(currency) { currency.strip.upcase }
  normalizes :buy_me_a_coffee_url, with: ->(url) { url.to_s.strip.presence }

  validates :name, presence: true
  validates :default_currency, presence: true
  validate :buy_me_a_coffee_url_is_supported

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

  private
    def buy_me_a_coffee_url_is_supported
      return if buy_me_a_coffee_url.blank?

      uri = URI.parse(buy_me_a_coffee_url)
      host = uri.host.to_s.downcase
      return if uri.is_a?(URI::HTTP) && BUY_ME_A_COFFEE_HOSTS.include?(host)

      errors.add(:buy_me_a_coffee_url, :invalid)
    rescue URI::InvalidURIError
      errors.add(:buy_me_a_coffee_url, :invalid)
    end
end
