class GrinderUse < ApplicationRecord
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  CONTEXT_ATTRIBUTES = %w[workspace_id user_id bean_id grinder_id method grind_setting].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :bean
  belongs_to :grinder, class_name: "Equipment", optional: true

  before_validation :set_occurrence, on: :create

  validates :confirmation_key, presence: true, format: { with: UUID_FORMAT }, uniqueness: { scope: %i[workspace_id user_id] }
  validates :method, inclusion: { in: Brew::BREW_METHODS }
  validates :occurred_at, presence: true
  validates :grind_setting, length: { maximum: 255 }
  validate :references_belong_to_workspace
  validate :grinder_is_present_and_valid, on: :create
  validate :confirmation_is_immutable, on: :update

  def matches_brew?(brew)
    CONTEXT_ATTRIBUTES.all? { |attribute| public_send(attribute) == brew.public_send(attribute) }
  end

  private
    def set_occurrence
      self.occurred_at ||= Time.current
    end

    def references_belong_to_workspace
      [ bean, grinder ].compact.each do |record|
        errors.add(:base, "References must belong to the workspace") if record.workspace_id != workspace_id
      end
    end

    def grinder_is_present_and_valid
      return if validation_context == :restore

      errors.add(:grinder, "must be a grinder") unless grinder&.grinder?
      errors.add(:bean, "must be whole bean") if bean&.pre_ground?
    end

    def confirmation_is_immutable
      if (CONTEXT_ATTRIBUTES + %w[confirmation_key occurred_at]).any? { |attribute| will_save_change_to_attribute?(attribute) }
        errors.add(:base, "Confirmed grinder uses cannot be changed")
      end
    end
end
