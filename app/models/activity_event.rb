class ActivityEvent < ApplicationRecord
  CATEGORIES = %w[
    coffee
    beans_inventory
    gear_maintenance
    sharing_recipes
    household_administration
    system_security
  ].freeze
  VISIBILITIES = %w[workspace workspace_admin instance_admin].freeze

  belongs_to :workspace, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :action, presence: true
  validates :occurred_at, presence: true
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
  validate :metadata_is_a_hash
  validate :visibility_matches_workspace_scope

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end

  private
    def metadata_is_a_hash
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end

    def visibility_matches_workspace_scope
      if visibility == "instance_admin"
        errors.add(:workspace, "must be blank for instance activity") if workspace_id.present?
      elsif visibility.present?
        errors.add(:workspace, "must be present for workspace activity") if workspace_id.blank?
      end
    end
end
