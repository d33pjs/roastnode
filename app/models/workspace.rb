require "uri"

class Workspace < ApplicationRecord
  BUY_ME_A_COFFEE_HOSTS = %w[buymeacoffee.com www.buymeacoffee.com].freeze
  BUY_ME_A_COFFEE_DISPLAY_MODES = %w[link official_badge].freeze
  BUY_ME_A_COFFEE_DEFAULT_TEXT = "Buy me a coffee"
  BUY_ME_A_COFFEE_SLUG_FORMAT = /\A[a-zA-Z0-9._-]+\z/

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
  normalizes :buy_me_a_coffee_display_mode, with: ->(mode) { mode.to_s.strip.presence || "link" }
  normalizes :buy_me_a_coffee_slug, with: ->(slug) { slug.to_s.strip.presence }
  normalizes :buy_me_a_coffee_text, with: ->(text) { text.to_s.strip.presence }

  validates :name, presence: true
  validates :default_currency, presence: true
  validates :buy_me_a_coffee_display_mode, inclusion: { in: BUY_ME_A_COFFEE_DISPLAY_MODES }
  validates :buy_me_a_coffee_slug,
    presence: true,
    length: { maximum: 100 },
    format: { with: BUY_ME_A_COFFEE_SLUG_FORMAT },
    if: :official_buy_me_a_coffee_badge?
  validates :buy_me_a_coffee_text, length: { maximum: 80 }, allow_blank: true
  validate :buy_me_a_coffee_url_is_supported

  def official_buy_me_a_coffee_badge?
    buy_me_a_coffee_display_mode == "official_badge"
  end

  def buy_me_a_coffee_badge_text
    buy_me_a_coffee_text.presence || BUY_ME_A_COFFEE_DEFAULT_TEXT
  end

  def site_footer_buy_me_a_coffee
    if official_buy_me_a_coffee_badge?
      return if buy_me_a_coffee_slug.blank?

      { mode: :official_badge, slug: buy_me_a_coffee_slug, text: buy_me_a_coffee_badge_text }
    elsif buy_me_a_coffee_url.present?
      { mode: :link, url: buy_me_a_coffee_url }
    end
  end

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
