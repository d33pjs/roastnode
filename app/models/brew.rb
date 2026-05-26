class Brew < ApplicationRecord
  RETENTION_TOLERANCE_GRAMS = BigDecimal("0.2")

  enum :method, {
    espresso: "espresso"
  }

  enum :taste_balance, {
    unknown: "unknown",
    very_sour: "very_sour",
    sour: "sour",
    neutral: "neutral",
    bitter: "bitter",
    very_bitter: "very_bitter"
  }

  enum :retention_marker, {
    unknown: "unknown",
    normal: "normal",
    retention: "retention",
    exchange: "exchange"
  }, prefix: :retention

  belongs_to :workspace
  belongs_to :user
  belongs_to :bean
  belongs_to :grinder, class_name: "Equipment", optional: true
  belongs_to :machine, class_name: "Equipment", optional: true

  has_one :inventory_adjustment, dependent: :restrict_with_exception
  has_many :brew_preparation_tools, dependent: :destroy
  has_many :preparation_tools, through: :brew_preparation_tools

  before_validation :set_defaults
  before_validation :set_retention_marker
  after_create :record_inventory_consumption

  validates :bean_weight_grams, numericality: { greater_than: 0 }
  validates :ground_weight_grams, :dose_grams, :beverage_grams, numericality: { greater_than: 0 }, allow_nil: true
  validates :brew_temperature_celsius, numericality: { greater_than: 0 }, allow_nil: true
  validates :total_time_seconds, :preinfusion_seconds, :first_drip_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, in: 0..5 }, allow_nil: true
  validate :bean_belongs_to_workspace
  validate :equipment_belongs_to_workspace
  validate :equipment_matches_expected_kind

  def snapshot_preparation_tools!(tools)
    brew_preparation_tools.destroy_all
    tools.each_with_index do |tool, index|
      brew_preparation_tools.create!(
        preparation_tool: tool,
        tool_name: tool.name,
        brew_method: tool.brew_method,
        position: index
      )
    end
  end

  private
    def set_defaults
      self.method ||= "espresso"
      self.occurred_at ||= Time.current
    end

    def set_retention_marker
      self.retention_marker = calculated_retention_marker
    end

    def calculated_retention_marker
      return "unknown" if bean_weight_grams.blank? || ground_weight_grams.blank?

      delta = ground_weight_grams - bean_weight_grams
      return "exchange" if delta > RETENTION_TOLERANCE_GRAMS
      return "retention" if delta < -RETENTION_TOLERANCE_GRAMS

      "normal"
    end

    def record_inventory_consumption
      bean.with_lock do
        bean.update!(remaining_grams: [ bean.remaining_grams - bean_weight_grams, 0 ].max)
        create_inventory_adjustment!(
          workspace:,
          bean:,
          user:,
          delta_grams: -bean_weight_grams,
          reason: "brew",
          note: "Brew consumption.",
          occurred_at:
        )
      end
    end

    def bean_belongs_to_workspace
      return if bean.blank? || workspace.blank? || bean.workspace_id == workspace_id

      errors.add(:bean, "must belong to the workspace")
    end

    def equipment_belongs_to_workspace
      [ grinder, machine ].compact.each do |item|
        errors.add(:base, "#{item.name} must belong to the workspace") if item.workspace_id != workspace_id
      end
    end

    def equipment_matches_expected_kind
      errors.add(:grinder, "must be a grinder") if grinder.present? && !grinder.grinder?
      errors.add(:machine, "must be a machine") if machine.present? && !machine.machine?
    end
end
