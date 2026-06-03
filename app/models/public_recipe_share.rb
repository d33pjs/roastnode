require "digest"

class PublicRecipeShare < ApplicationRecord
  has_secure_password :password, validations: false

  belongs_to :workspace
  belongs_to :recipe
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  before_validation :set_token, on: :create
  before_validation :set_token_digest
  before_validation :set_workspace_from_recipe

  validates :token, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true
  validates :recipe_id, uniqueness: true
  validates :password, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_blank: true
  validate :recipe_belongs_to_workspace

  def self.find_enabled_by_token!(token)
    find_by!(token_digest: token_digest_for(token), enabled: true)
  end

  def self.token_digest_for(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def password_protected?
    password_digest.present?
  end

  def password_unlock_fingerprint
    return unless password_protected?

    Digest::SHA256.hexdigest(password_digest)
  end

  def manageable_by?(user)
    membership = user&.membership_for(workspace)
    return false unless membership

    policy = WorkspacePolicy.new(membership)
    policy.manage? || (policy.write? && recipe.created_by_id == user.id)
  end

  def refresh_snapshot!(title:, selected_photo_attachment_ids: [], updated_by:)
    update!(
      title:,
      selected_photo_attachment_ids: Array(selected_photo_attachment_ids).map(&:to_i).uniq,
      updated_by:,
      snapshot: PublicRecipeShareSnapshotBuilder.new(
        recipe:,
        title:,
        selected_photo_attachment_ids:
      ).call
    )
  end

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_token_digest
      self.token_digest = self.class.token_digest_for(token) if token.present?
    end

    def set_workspace_from_recipe
      self.workspace ||= recipe.workspace if recipe
    end

    def recipe_belongs_to_workspace
      return if recipe.blank? || workspace.blank? || recipe.workspace_id == workspace_id

      errors.add(:recipe, "must belong to the workspace")
    end
end
