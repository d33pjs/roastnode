require "digest"

class WorkspaceInvite < ApplicationRecord
  INVITABLE_ROLES = %w[admin member viewer].freeze
  ROLE_PRIORITY = {
    "viewer" => 0,
    "member" => 1,
    "admin" => 2,
    "owner" => 3
  }.freeze

  enum :role, {
    admin: "admin",
    member: "member",
    viewer: "viewer"
  }

  belongs_to :workspace
  belongs_to :created_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true

  before_validation :set_token, on: :create
  before_validation :set_token_digest
  before_validation :set_expiration, on: :create

  validates :role, presence: true, inclusion: { in: INVITABLE_ROLES }
  validates :token, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :email_address, with: ->(email) { email.presence&.strip&.downcase }

  scope :matching_token, ->(token) { where(token_digest: token_digest_for(token)) }

  def self.token_digest_for(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def acceptable?
    accepted_at.blank? && revoked_at.blank? && expires_at.future?
  end

  def acceptable_for?(user)
    acceptable? && (email_address.blank? || normalized_email(user&.email_address) == email_address)
  end

  def accept!(user)
    unless acceptable_for?(user)
      errors.add(:base, "is not available for this email") if acceptable? && email_address.present?
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      membership = user.memberships.find_or_initialize_by(workspace:)
      membership.role = role if membership.new_record? || role_priority(role) > role_priority(membership.role)
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

    def set_token_digest
      self.token_digest = self.class.token_digest_for(token) if token.present?
    end

    def set_expiration
      self.expires_at ||= 7.days.from_now
    end

    def role_priority(role)
      ROLE_PRIORITY.fetch(role)
    end

    def normalized_email(value)
      value.to_s.strip.downcase
    end
end
