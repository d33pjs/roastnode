class Brew < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  RETENTION_TOLERANCE_GRAMS = BigDecimal("0.2")
  TYPICAL_GRAMS_PER_COFFEE_SPOON = BigDecimal("5")

  enum :method, {
    espresso: "espresso",
    quick_drip: "quick_drip"
  }

  BREW_METHODS = %w[espresso quick_drip].freeze

  enum :coffee_amount_source, {
    measured: "measured",
    estimated_spoons: "estimated_spoons"
  }, prefix: :coffee_amount

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
  belongs_to :data_import, optional: true
  belongs_to :bean
  belongs_to :grinder, class_name: "Equipment", optional: true
  belongs_to :machine, class_name: "Equipment", optional: true
  belongs_to :brewer, class_name: "Equipment", optional: true
  belongs_to :recipe, optional: true

  has_one :inventory_adjustment, dependent: :restrict_with_exception
  has_one :public_brew_share, dependent: :destroy
  has_many :brew_preparation_tools, dependent: :destroy
  has_many :preparation_tools, through: :brew_preparation_tools
  has_many_attached :photos

  before_validation :set_defaults
  before_validation :set_quick_drip_consumed_grams
  before_validation :set_retention_marker
  after_save :clear_quick_drip_amount_assignment_flags
  after_create :record_inventory_consumption

  validates :bean_weight_grams, numericality: { greater_than: 0 }
  validates :ground_weight_grams, :dose_grams, :beverage_grams, numericality: { greater_than: 0 }, allow_nil: true
  validates :machine_cups, numericality: { greater_than: 0 }, allow_nil: true
  validates :coffee_spoons, :grams_per_coffee_spoon, numericality: { greater_than: 0 }, allow_nil: true
  validates :brew_temperature_celsius, numericality: { greater_than: 0 }, allow_nil: true
  validates :total_time_seconds, :preinfusion_seconds, :first_drip_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true
  validate :quick_drip_required_fields
  validate :bean_belongs_to_workspace
  validate :equipment_belongs_to_workspace
  validate :equipment_matches_expected_kind
  validate :method_specific_equipment
  validate :recipe_belongs_to_workspace

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

  def update_with_inventory_correction!(attributes, preparation_tools:)
    transaction do
      old_bean = bean
      old_weight = bean_weight_grams

      update!(attributes)

      correct_inventory!(old_bean:, old_weight:, new_bean: bean, new_weight: bean_weight_grams)
      sync_inventory_adjustment!
      snapshot_preparation_tools!(preparation_tools)
    end
  end

  def destroy_with_inventory_reversal!
    transaction do
      restore_inventory!(bean, bean_weight_grams)
      inventory_adjustment&.destroy!
      association(:inventory_adjustment).reset
      destroy!
    end
  end

  def bean_weight_grams=(value)
    @quick_drip_spoon_estimate_assigned = false unless @assigning_quick_drip_spoon_estimate
    super
  end

  private
    def set_defaults
      self.method ||= "espresso"
      self.occurred_at ||= Time.current
    end

    def set_retention_marker
      self.retention_marker = calculated_retention_marker
    end

    def set_quick_drip_consumed_grams
      return unless quick_drip?

      if quick_drip_measured_amount?
        self.coffee_amount_source = "measured"
        self.grams_per_coffee_spoon = spoon_grams_for_snapshot if coffee_spoons.present? && grams_per_coffee_spoon.blank?
        return
      end

      return if preserve_quick_drip_spoon_estimate?
      return if coffee_spoons.blank?

      spoon_grams = spoon_grams_for_snapshot
      self.grams_per_coffee_spoon = spoon_grams
      assign_quick_drip_spoon_estimate!(coffee_spoons.to_d * spoon_grams)
      self.coffee_amount_source = "estimated_spoons"
    end

    def quick_drip_measured_amount?
      return false if bean_weight_grams.blank?

      return true if coffee_amount_measured?

      will_save_change_to_bean_weight_grams? && !@quick_drip_spoon_estimate_assigned
    end

    def preserve_quick_drip_spoon_estimate?
      persisted? && coffee_amount_estimated_spoons? && !quick_drip_spoon_fields_changed?
    end

    def quick_drip_spoon_fields_changed?
      will_save_change_to_coffee_spoons? || will_save_change_to_grams_per_coffee_spoon?
    end

    def assign_quick_drip_spoon_estimate!(amount)
      @assigning_quick_drip_spoon_estimate = true
      self.bean_weight_grams = amount.round(2)
      @quick_drip_spoon_estimate_assigned = true
    ensure
      @assigning_quick_drip_spoon_estimate = false
    end

    def spoon_grams_for_snapshot
      grams_per_coffee_spoon.presence || user&.grams_per_coffee_spoon.presence || TYPICAL_GRAMS_PER_COFFEE_SPOON
    end

    def calculated_retention_marker
      return "unknown" unless espresso?
      return "unknown" if bean_weight_grams.blank? || ground_weight_grams.blank?

      delta = ground_weight_grams - bean_weight_grams
      return "exchange" if delta > RETENTION_TOLERANCE_GRAMS
      return "retention" if delta < -RETENTION_TOLERANCE_GRAMS

      "normal"
    end

    def record_inventory_consumption
      deduct_inventory!(bean, bean_weight_grams)
      sync_inventory_adjustment!
    end

    def correct_inventory!(old_bean:, old_weight:, new_bean:, new_weight:)
      restore_inventory!(old_bean, old_weight)
      deduct_inventory!(new_bean, new_weight)
    end

    def restore_inventory!(target_bean, amount)
      target_bean.with_lock do
        target_bean.update!(remaining_grams: target_bean.remaining_grams + amount)
      end
    end

    def deduct_inventory!(target_bean, amount)
      target_bean.with_lock do
        target_bean.update!(remaining_grams: [ target_bean.remaining_grams - amount, 0 ].max)
      end
    end

    def sync_inventory_adjustment!
      adjustment = inventory_adjustment || build_inventory_adjustment(workspace:, user:, reason: "brew", note: "Brew consumption.")
      adjustment.update!(
        workspace:,
        bean:,
        user:,
        delta_grams: -bean_weight_grams,
        reason: "brew",
        note: "Brew consumption.",
        occurred_at:
      )
    end

    def bean_belongs_to_workspace
      return if bean.blank? || workspace.blank? || bean.workspace_id == workspace_id

      errors.add(:bean, "must belong to the workspace")
    end

    def equipment_belongs_to_workspace
      [ grinder, machine, brewer ].compact.each do |item|
        errors.add(:base, "#{item.name} must belong to the workspace") if item.workspace_id != workspace_id
      end
    end

    def equipment_matches_expected_kind
      errors.add(:grinder, "must be a grinder") if grinder.present? && !grinder.grinder?
      errors.add(:machine, "must be a machine") if machine.present? && !quick_drip? && !machine.machine?
    end

    def quick_drip_required_fields
      return unless quick_drip?

      errors.add(:brewer, "must be selected") if brewer.blank?
      errors.add(:machine_cups, "must be greater than 0") if machine_cups.blank?
      if bean_weight_grams.blank? && coffee_spoons.blank?
        errors.add(:base, "Quick Drip requires coffee spoons or measured ground coffee")
      end
    end

    def method_specific_equipment
      if quick_drip?
        errors.add(:brewer, "must be a brewer") if brewer.present? && !brewer.brewer?
        errors.add(:machine, "is only used for espresso") if machine.present?
      elsif espresso?
        errors.add(:brewer, "must be a brewer") if brewer.present? && !brewer.brewer?
        errors.add(:brewer, "is only used for Quick Drip") if brewer.present?
      end
    end

    def recipe_belongs_to_workspace
      return if recipe.blank? || workspace.blank? || recipe.workspace_id == workspace_id

      errors.add(:recipe, "must belong to the workspace")
    end

    def clear_quick_drip_amount_assignment_flags
      @quick_drip_spoon_estimate_assigned = false
      @assigning_quick_drip_spoon_estimate = false
    end
end
