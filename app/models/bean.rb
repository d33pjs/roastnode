class Bean < ApplicationRecord
  ROAST_TYPES = %w[unknown espresso filter omni].freeze
  BLEND_TYPES = %w[unknown single_origin blend].freeze
  DUPLICATE_DISPLAY_DATE_FORMAT = "%d.%m.%Y"

  belongs_to :workspace
  belongs_to :data_import, optional: true

  has_many :brews, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception
  has_many_attached :photos

  before_validation :set_default_remaining_grams

  scope :open, -> { where(archived_at: nil).where("remaining_grams > 0").order(Arel.sql("opened_on ASC NULLS LAST"), :created_at) }
  scope :recent, -> { order(created_at: :desc) }

  validates :name, presence: true
  validates :bag_size_grams, numericality: { greater_than: 0 }
  validates :remaining_grams, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :roast_type, inclusion: { in: ROAST_TYPES }
  validates :blend_type, inclusion: { in: BLEND_TYPES }
  validates :roast_degree, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validate :roast_degree_half_step
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true

  def open?
    archived_at.blank? && remaining_grams.positive?
  end

  def close!
    update!(archived_at: Time.current)
  end

  def reopen!
    self.remaining_grams = bag_size_grams if remaining_grams.to_d <= 0
    self.archived_at = nil
    save!
  end

  def duplicate_for_new_bag!
    duplicate = nil

    transaction do
      duplicate = workspace.beans.create!(duplicate_attributes)
      duplicate.photos.attach(photos.map(&:blob)) if photos.attached?
    end

    duplicate
  end

  def display_name
    [ roaster_name, name ].compact_blank.join(" - ")
  end

  def display_name_for_collection(beans)
    return display_name unless duplicate_display_name_in?(beans)

    "#{display_name} (opened #{opened_on&.strftime(DUPLICATE_DISPLAY_DATE_FORMAT) || "unknown"})"
  end

  private
    def set_default_remaining_grams
      self.remaining_grams = bag_size_grams if remaining_grams.nil? && bag_size_grams.present?
    end

    def roast_degree_half_step
      return if roast_degree.blank?
      return if (roast_degree.to_d * 2) % 1 == 0

      errors.add(:roast_degree, "must use half-step increments")
    end

    def duplicate_attributes
      {
        name:,
        roaster_name:,
        origin:,
        process:,
        roast_date:,
        roast_level:,
        tasting_notes:,
        bag_size_grams:,
        remaining_grams: bag_size_grams,
        opened_on: Date.current,
        purchase_source:,
        purchase_url:,
        purchased_on:,
        purchase_price_cents:,
        rating:,
        notes:,
        roast_type:,
        roast_degree:,
        blend_type:,
        decaffeinated:,
        country:,
        region:,
        farm:,
        farmer:,
        elevation:,
        variety:,
        harvested:,
        blend_percentage:
      }
    end

    def duplicate_display_name_in?(beans)
      beans.count do |bean|
        bean.open? && bean.display_name == display_name
      end > 1
    end
end
