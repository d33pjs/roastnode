class ExternalCoffee < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  ACIDITY_BALANCES = %w[unknown very_sour sour balanced bitter very_bitter].freeze
  INTENSITIES = %w[unknown weak balanced strong harsh].freeze

  enum :acidity_balance, ACIDITY_BALANCES.index_by(&:itself)
  enum :intensity, INTENSITIES.index_by(&:itself), prefix: true

  belongs_to :workspace
  belongs_to :user

  has_many_attached :photos

  before_validation :set_defaults

  normalizes :drink_type, with: ->(value) { value.to_s.strip.presence }
  normalizes :drink_size, with: ->(value) { value.to_s.strip.presence }
  normalizes :place_name, with: ->(value) { value.to_s.strip.presence }
  normalizes :place_location, with: ->(value) { value.to_s.strip.presence }
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :drink_type, presence: true, length: { maximum: 120 }
  validates :drink_size, :place_name, :place_location, length: { maximum: 160 }
  validates :currency, presence: true, length: { is: 3 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :acidity_balance, inclusion: { in: ACIDITY_BALANCES }
  validates :intensity, inclusion: { in: INTENSITIES }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validate :user_belongs_to_workspace

  scope :recent, -> { order(occurred_at: :desc, created_at: :desc) }

  def price
    return if price_cents.blank?

    price_cents.to_d / 100
  end

  def price=(value)
    self.price_cents = if value.blank?
      nil
    else
      (BigDecimal(LocalizedNumberParser.normalize_decimal(value).to_s) * 100).round
    end
  end

  def display_name
    [ drink_type, place_name ].compact_blank.join(" at ")
  end

  private
    def set_defaults
      self.occurred_at ||= Time.current
      self.currency ||= workspace&.default_currency
      self.acidity_balance ||= "unknown"
      self.intensity ||= "unknown"
    end

    def user_belongs_to_workspace
      return if user.blank? || workspace.blank?
      return if user.memberships.exists?(workspace_id: workspace_id)

      errors.add(:user, "must belong to the workspace")
    end
end
