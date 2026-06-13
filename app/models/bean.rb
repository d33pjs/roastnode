class Bean < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  ROAST_TYPES = %w[unknown espresso filter omni].freeze
  BLEND_TYPES = %w[unknown single_origin blend].freeze
  BAG_STATUSES = %w[stock open finished used_up archived].freeze
  GRIND_STATES = %w[whole_bean pre_ground].freeze
  DUPLICATE_DISPLAY_DATE_FORMAT = "%d.%m.%Y"
  LOW_REMAINING_GRAMS = BigDecimal("18")
  DEFAULT_SHOT_COST_GRAMS = BigDecimal("18")

  belongs_to :workspace
  belongs_to :data_import, optional: true
  belongs_to :duplicated_from_bean, class_name: "Bean", optional: true, inverse_of: :duplicated_bean_bags

  has_many :brews, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception
  has_many :duplicated_bean_bags, class_name: "Bean", foreign_key: :duplicated_from_bean_id, dependent: :nullify, inverse_of: :duplicated_from_bean
  has_one :public_bean_share, dependent: :destroy
  has_many_attached :photos

  before_validation :set_default_remaining_grams
  normalizes :purchase_url, with: ->(url) { url.to_s.strip.presence }

  scope :open, -> { where(archived_at: nil, finished_at: nil).where.not(opened_on: nil).where("remaining_grams > 0").order(Arel.sql("opened_on ASC NULLS LAST"), :created_at) }
  scope :recent, -> { order(created_at: :desc) }

  def self.safe_purchase_url(url)
    url = url.to_s.strip
    return if url.blank?

    url if valid_purchase_url?(url)
  end

  def self.valid_purchase_url?(url)
    uri = URI.parse(url.to_s.strip)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  validates :name, presence: true
  validates :bag_size_grams, numericality: { greater_than: 0 }
  validates :remaining_grams, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :roast_type, inclusion: { in: ROAST_TYPES }
  validates :blend_type, inclusion: { in: BLEND_TYPES }
  validates :grind_state, inclusion: { in: GRIND_STATES }
  validates :roast_degree, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validate :roast_degree_half_step
  validate :purchase_url_is_http_or_https, if: :will_save_change_to_purchase_url?
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true

  def open?
    bag_status == "open"
  end

  def stock?
    bag_status == "stock"
  end

  def used_up?
    bag_status == "used_up"
  end

  def finished?
    bag_status == "finished"
  end

  def archived?
    bag_status == "archived"
  end

  def pre_ground?
    grind_state == "pre_ground"
  end

  def bag_status
    return "archived" if archived_at.present?
    return "finished" if finished_at.present?
    return "used_up" if remaining_grams.present? && remaining_grams <= 0
    return "open" if opened_on.present?

    "stock"
  end

  def apply_bag_status(status)
    return if status.blank?

    status = status.to_s
    raise ArgumentError, "unknown bag status: #{status}" unless BAG_STATUSES.include?(status)

    case status
    when "stock"
      self.archived_at = nil
      self.finished_at = nil
      self.opened_on = nil
      self.remaining_grams = bag_size_grams if remaining_grams.blank? || remaining_grams <= 0
    when "open"
      self.archived_at = nil
      self.finished_at = nil
      self.opened_on ||= Date.current
      self.remaining_grams = bag_size_grams if remaining_grams.blank? || remaining_grams <= 0
    when "finished"
      self.archived_at = nil
      self.finished_at ||= Time.current
      self.opened_on ||= Date.current
    when "used_up"
      self.archived_at = nil
      self.finished_at = nil
      self.opened_on ||= Date.current
      self.remaining_grams = 0
    when "archived"
      self.finished_at = nil
      self.archived_at ||= Time.current
    end
  end

  def close!
    archive!
  end

  def archive!
    update_columns(
      archived_at: Time.current,
      finished_at: nil,
      updated_at: Time.current
    )
  end

  def finish!
    update_columns(
      archived_at: nil,
      finished_at: Time.current,
      opened_on: opened_on || Date.current,
      updated_at: Time.current
    )
  end

  def reopen!
    update_columns(
      remaining_grams: remaining_grams.to_d <= 0 ? bag_size_grams : remaining_grams,
      archived_at: nil,
      finished_at: nil,
      opened_on: opened_on || Date.current,
      updated_at: Time.current
    )
  end

  def open_bag!
    update_columns(
      archived_at: nil,
      finished_at: nil,
      opened_on: Date.current,
      remaining_grams: remaining_grams.blank? || remaining_grams.to_d <= 0 ? bag_size_grams : remaining_grams,
      updated_at: Time.current
    )
  end

  def origin_display_value
    country.presence || region.presence || continent.presence || origin.presence
  end

  def remaining_percent
    return 0.to_d if bag_size_grams.blank? || bag_size_grams.to_d <= 0

    percent = (remaining_grams.to_d / bag_size_grams.to_d) * 100
    [ [ percent, 0.to_d ].max, 100.to_d ].min.round
  end

  def nearly_finished?(threshold_grams = LOW_REMAINING_GRAMS)
    !stock? && !archived? && remaining_grams.to_d <= threshold_grams.to_d
  end

  def finished_used_grams
    return if bag_size_grams.blank? || remaining_grams.blank?

    [ bag_size_grams.to_d - remaining_grams.to_d, 0.to_d ].max
  end

  def finished_open_days
    return if finished_at.blank? || opened_on.blank?

    [ (finished_at.to_date - opened_on).to_i, 1 ].max
  end

  def finished_grams_per_day
    return if finished_used_grams.blank? || finished_open_days.blank?

    (finished_used_grams / finished_open_days).round(2)
  end

  def duplicate_for_new_bag!
    duplicate = nil

    transaction do
      duplicate = workspace.beans.create!(duplicate_attributes)
      if photos.attached?
        duplicate.photos.attach(photos.map(&:blob))
        if primary_photo_attachment.present?
          primary_blob_id = primary_photo_attachment.blob_id
          duplicate_primary = duplicate.photos.attachments.detect { |attachment| attachment.blob_id == primary_blob_id }
          duplicate.update!(primary_photo_attachment_id: duplicate_primary.id) if duplicate_primary
        end
      end
    end

    duplicate
  end

  def destroy_with_history!
    transaction do
      brews_to_destroy = brews.to_a

      inventory_adjustments.destroy_all
      brews_to_destroy.each do |brew|
        brew.association(:inventory_adjustment).reset
        brew.destroy!
      end
      association(:brews).reset
      destroy!
    end
  end

  def display_name
    [ roaster_name, name ].compact_blank.join(" - ")
  end

  def purchase_price
    return if purchase_price_cents.blank?

    purchase_price_cents.to_d / 100
  end

  def purchase_price=(value)
    self.purchase_price_cents = if value.blank?
      nil
    else
      (BigDecimal(LocalizedNumberParser.normalize_decimal(value).to_s) * 100).round
    end
  end

  def cost_per_package
    purchase_price
  end

  def cost_per_kg
    return if purchase_price.blank? || bag_size_grams.blank? || bag_size_grams.to_d <= 0

    ((purchase_price.to_d / bag_size_grams.to_d) * 1000).round(2)
  end

  def average_logged_bean_weight_grams
    weights = brews.where.not(bean_weight_grams: nil).pluck(:bean_weight_grams).map(&:to_d)
    return if weights.empty?

    (weights.sum / weights.size).round(2)
  end

  def shot_weight_for_cost
    average_logged_bean_weight_grams || DEFAULT_SHOT_COST_GRAMS
  end

  def cost_per_shot
    return if purchase_price.blank? || bag_size_grams.blank? || bag_size_grams.to_d <= 0

    ((purchase_price.to_d / bag_size_grams.to_d) * shot_weight_for_cost).round(2)
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

    def purchase_url_is_http_or_https
      return if purchase_url.blank?
      return if self.class.valid_purchase_url?(purchase_url)

      errors.add(:purchase_url, "must be an HTTP or HTTPS URL")
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
        purchase_url: self.class.safe_purchase_url(purchase_url),
        purchased_on:,
        purchase_price_cents:,
        rating:,
        notes:,
        roast_type:,
        roast_degree:,
        blend_type:,
        decaffeinated:,
        grind_state:,
        country:,
        continent:,
        region:,
        farm:,
        farmer:,
        elevation:,
        variety:,
        harvested:,
        blend_percentage:,
        country_of_manufacturer:,
        manufacturer:,
        duplicated_from_bean: self
      }
    end

    def duplicate_display_name_in?(beans)
      beans.count do |bean|
        bean.open? && bean.display_name == display_name
      end > 1
    end
end
