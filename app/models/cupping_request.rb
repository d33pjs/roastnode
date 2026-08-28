require "digest"

class CuppingRequest < ApplicationRecord
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
end
