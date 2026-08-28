require "digest"
require "openssl"

class CuppingRequest < ApplicationRecord
  EXPIRATION_DISPATCH_LEASE = 5.minutes

  belongs_to :workspace
  belongs_to :brew

  before_validation :set_token, on: :create
  before_validation :set_token_digest
  before_validation :set_workspace_from_brew

  validates :token, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true
  validates :brew_id, uniqueness: true
  validates :feedback_comment, length: { maximum: 2_000 }, allow_nil: true
  validate :brew_belongs_to_workspace
  validate :brew_must_be_guest_espresso

  class << self
    def find_by_token!(token)
      joins(:brew)
        .where("cupping_requests.workspace_id = brews.workspace_id")
        .find_by!(
          token_digest: token_digest_for(token),
          brews: { method: "espresso", recipient_kind: "guest" }
        )
    end

    def token_digest_for(token)
      Digest::SHA256.hexdigest(token.to_s)
    end
  end

  def eligible?
    brew.present? && workspace.present? && brew.workspace_id == workspace_id && brew.espresso? && brew.recipient_guest?
  end

  def feedback_open?(at: Time.current)
    opened_at.present? && feedback_expires_at.present? && closed_at.blank? && at < feedback_expires_at
  end

  def expiration_dispatch_pending?(at: Time.current)
    expiration_job_enqueued_at.blank? &&
      closed_at.blank? &&
      feedback_expires_at.present? &&
      at < feedback_expires_at &&
      (expiration_job_enqueueing_at.blank? || expiration_job_enqueueing_at <= at - EXPIRATION_DISPATCH_LEASE)
  end

  def claim_expiration_dispatch!(at: Time.current)
    update!(expiration_job_enqueueing_at: at)
    expiration_job_enqueueing_at
  end

  def guest_label
    brew&.recipient_name.to_s.strip.presence || "Guest"
  end

  def refresh_snapshot!
    update!(
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: PublicBrewShare.default_title_for(brew),
        selected_photo_attachment_ids: []
      ).call
    )
  end

  def public_attachment_ids
    snapshot_payload = snapshot.is_a?(Hash) ? snapshot : {}
    public_media_payload = snapshot_payload.fetch("public_media", [])

    collect_attachment_ids(public_media_payload).map(&:to_i).uniq & current_public_identity_attachment_ids
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

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_token_digest
      self.token_digest = self.class.token_digest_for(token) if token.present?
    end

    def set_workspace_from_brew
      self.workspace ||= brew.workspace if brew
    end

    def brew_belongs_to_workspace
      return if brew.blank? || workspace.blank? || brew.workspace_id == workspace_id

      errors.add(:brew, "must belong to the workspace")
    end

    def brew_must_be_guest_espresso
      return if brew.blank? || (brew.espresso? && brew.recipient_guest?)

      errors.add(:brew, "must be a guest espresso brew")
    end

    def current_public_identity_attachment_ids
      [
        workspace&.logo&.attachment&.id,
        brew&.user&.avatar&.attachment&.id
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

    def media_handle_for_attachment_id(attachment_id)
      OpenSSL::HMAC.hexdigest("SHA256", public_media_handle_secret, "#{token}:#{attachment_id}").first(32)
    end

    def public_media_handle_secret
      Rails.application.key_generator.generate_key("public-cupping-request-media-handle")
    end
end
