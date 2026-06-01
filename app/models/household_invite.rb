class HouseholdInvite < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true
  belongs_to :workspace, optional: true

  before_validation :set_token, on: :create
  before_validation :set_expiration, on: :create

  validates :email_address, presence: true
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :email_address, with: ->(email) { email.presence&.strip&.downcase }

  def acceptable?
    accepted_at.blank? && revoked_at.blank? && expires_at.future?
  end

  def acceptable_for?(user)
    acceptable? && normalized_email(user&.email_address) == email_address
  end

  def accept!(user, workspace:)
    with_lock do
      unless acceptable_for?(user)
        errors.add(:base, "is not available for this email")
        raise ActiveRecord::RecordInvalid, self
      end

      unless workspace.new_record?
        errors.add(:workspace, "must be new")
        raise ActiveRecord::RecordInvalid, self
      end

      workspace.kind = :household
      workspace.default_currency = "EUR"
      workspace.save!

      user.memberships.create!(workspace:, role: :owner)
      update!(accepted_by: user, accepted_at: Time.current, workspace:)
      user.update!(active_workspace: workspace)

      workspace
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_expiration
      self.expires_at ||= 7.days.from_now
    end

    def normalized_email(value)
      value.to_s.strip.downcase
    end
end
