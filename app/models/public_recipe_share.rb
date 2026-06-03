require "digest"
require "openssl"

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

  def public_attachment_ids
    snapshot_media_attachment_ids.presence || selected_recipe_photo_attachment_ids
  end

  def public_media_handle_for(attachment_id)
    attachment_id = attachment_id.to_i
    return unless public_attachment_ids.include?(attachment_id)

    media_handle_for_attachment_id(attachment_id)
  end

  def public_attachment_id_for_media_handle(handle)
    handle = handle.to_s
    return if handle.blank?

    public_attachment_ids.find do |attachment_id|
      expected = media_handle_for_attachment_id(attachment_id)
      handle.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(handle, expected)
    end
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

    def snapshot_media_attachment_ids
      snapshot_payload = snapshot.is_a?(Hash) ? snapshot : {}
      collect_attachment_ids(snapshot_payload.fetch("public_media", [])).map(&:to_i).uniq & selected_recipe_photo_attachment_ids
    end

    def selected_recipe_photo_attachment_ids
      selected_ids = Array(selected_photo_attachment_ids).map(&:to_i)
      recipe.photos.attachments.map(&:id) & selected_ids
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end

    def media_handle_for_attachment_id(attachment_id)
      OpenSSL::HMAC.hexdigest("SHA256", public_media_handle_secret, "#{token}:#{attachment_id}").first(32)
    end

    def public_media_handle_secret
      Rails.application.key_generator.generate_key("public-recipe-share-media-handle")
    end
end
