class Bean < ApplicationRecord
  belongs_to :workspace

  has_many :brews, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception

  before_validation :set_default_remaining_grams

  scope :open, -> { where(archived_at: nil).where("remaining_grams > 0").order(Arel.sql("opened_on ASC NULLS LAST"), :created_at) }
  scope :recent, -> { order(created_at: :desc) }

  validates :name, presence: true
  validates :bag_size_grams, numericality: { greater_than: 0 }
  validates :remaining_grams, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, in: 0..5 }, allow_nil: true

  def open?
    archived_at.blank? && remaining_grams.positive?
  end

  private
    def set_default_remaining_grams
      self.remaining_grams = bag_size_grams if remaining_grams.nil? && bag_size_grams.present?
    end
end
