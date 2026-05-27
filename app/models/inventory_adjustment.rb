class InventoryAdjustment < ApplicationRecord
  enum :reason, {
    brew: "brew",
    manual: "manual"
  }

  belongs_to :workspace
  belongs_to :bean
  belongs_to :user
  belongs_to :brew, optional: true

  before_validation :set_occurred_at

  validates :delta_grams, numericality: { other_than: 0 }
  validates :reason, presence: true
  validate :bean_belongs_to_workspace
  validate :brew_belongs_to_workspace

  def save_with_inventory_update
    return false unless valid?

    transaction do
      save!
      update_bean_inventory! if manual?
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private
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

    def update_bean_inventory!
      bean.with_lock do
        bean.update!(remaining_grams: [ bean.remaining_grams + delta_grams, 0 ].max)
      end
    end
end
