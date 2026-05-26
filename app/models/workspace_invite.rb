class WorkspaceInvite < ApplicationRecord
  INVITABLE_ROLES = %w[admin member viewer].freeze

  enum :role, {
    admin: "admin",
    member: "member",
    viewer: "viewer"
  }

  belongs_to :workspace
  belongs_to :created_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true

  before_validation :set_token, on: :create
  before_validation :set_expiration, on: :create

  validates :role, presence: true, inclusion: { in: INVITABLE_ROLES }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :email_address, with: ->(email) { email.presence&.strip&.downcase }

  def acceptable?
    accepted_at.blank? && revoked_at.blank? && expires_at.future?
  end

  def accept!(user)
    raise ActiveRecord::RecordInvalid, self unless acceptable?

    transaction do
      membership = user.memberships.find_or_initialize_by(workspace:)
      membership.role = role
      membership.save!

      update!(accepted_by: user, accepted_at: Time.current)

      membership
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
end

