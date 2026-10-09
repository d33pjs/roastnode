class InventoryAdjustment < ApplicationRecord
  enum :reason, {
    brew: "brew",
    manual: "manual",
    transfer: "transfer"
  }

  attr_accessor :adjustment_mode, :target_remaining_grams

  belongs_to :workspace
  belongs_to :bean
  belongs_to :user
  belongs_to :brew, optional: true

  before_validation :set_occurred_at

  validates :adjustment_mode, inclusion: { in: %w[delta set_remaining] }, allow_nil: true
  validates :target_remaining_grams, numericality: { greater_than_or_equal_to: 0 }, if: :set_remaining?
  validates :delta_grams, numericality: { other_than: 0 }, unless: :set_remaining?
  validates :reason, presence: true
  validate :bean_belongs_to_workspace
  validate :brew_belongs_to_workspace

  def save_with_inventory_update
    bean.with_lock do
      return false unless valid?
      self.delta_grams = target_remaining_grams.to_d - bean.remaining_grams if set_remaining?
      return true if set_remaining? && delta_grams.zero?

      save!
      bean.update!(remaining_grams: [ bean.remaining_grams + delta_grams, 0 ].max) if manual?
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private
    def set_remaining?
      manual? && adjustment_mode == "set_remaining"
    end

    def set_occurred_at
      self.occurred_at ||= Time.current
    end

    def bean_belongs_to_workspace
      return if bean.blank? || workspace.blank? || bean.workspace_id == workspace_id

      errors.add(:bean, "must belong to the workspace")
    end

    def brew_belongs_to_workspace
      return if brew.blank? || workspace.blank? || brew.workspace_id == workspace_id

      errors.add(:brew, "must belong to the workspace")
    end
end
