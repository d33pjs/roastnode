require "digest"

class PublicBrewShare < ApplicationRecord
  has_secure_password :password, validations: false

  belongs_to :workspace
  belongs_to :brew
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  before_validation :set_token, on: :create
  before_validation :set_workspace_from_brew

  validates :token, presence: true, uniqueness: true
  validate :brew_belongs_to_workspace

  validates :brew_id, uniqueness: true
  validates :password, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_blank: true

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
    policy.manage? || (policy.write? && brew.user_id == user.id)
  end

  def public_attachment_ids
    collect_attachment_ids(snapshot).uniq & allowed_public_attachment_ids
  end

  def refresh_snapshot!(title:, selected_photo_attachment_ids:, updated_by:)
    update!(
      title:,
      selected_photo_attachment_ids: Array(selected_photo_attachment_ids).map(&:to_i).uniq,
      updated_by:,
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew:,
        title:,
        selected_photo_attachment_ids:
      ).call
    )
  end

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_workspace_from_brew
      self.workspace ||= brew.workspace if brew
    end

    def brew_belongs_to_workspace
      return if brew.blank? || workspace.blank? || brew.workspace_id == workspace_id

      errors.add(:brew, "must belong to the workspace")
    end

    def allowed_public_attachment_ids
      public_identity_attachment_ids + selected_share_record_photo_attachment_ids
    end

    def public_identity_attachment_ids
      [
        workspace&.logo&.attachment&.id,
        brew&.user&.avatar&.attachment&.id
      ].compact
    end

    def selected_share_record_photo_attachment_ids
      selected_ids = Array(selected_photo_attachment_ids).map(&:to_i)
      share_record_photo_attachment_ids & selected_ids
    end

    def share_record_photo_attachment_ids
      share_photo_records.flat_map { |record| record.photos.attachments.map(&:id) }
    end

    def share_photo_records
      [
        brew,
        brew&.bean,
        brew&.grinder,
        brew&.machine,
        *Array(brew&.preparation_tools)
      ].compact
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
end
