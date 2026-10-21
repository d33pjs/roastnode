require "digest"

class PublicBeanCollection < ApplicationRecord
  belongs_to :workspace

  before_validation :prepare_settings
  before_save :build_snapshot

  validates :workspace_id, uniqueness: true
  validates :token, :token_digest, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 3000 }
  validates :mode, inclusion: { in: %w[selected automatic] }
  validate :selections_belong_to_workspace

  def self.find_enabled_by_token!(token)
    find_by!(token_digest: Digest::SHA256.hexdigest(token.to_s), enabled: true)
  end

  def eligible_shares
    workspace.public_bean_shares.joins(:bean)
      .where(enabled: true, password_digest: nil).where.not(beans: { opened_on: nil })
  end

  def self.defer_refreshes
    state = ActiveSupport::IsolatedExecutionState
    return yield if state[:bean_collection_refreshes]

    pending = Set.new
    state[:bean_collection_refreshes] = pending
    begin
      result = yield
      where(workspace_id: pending.to_a).find_each(&:refresh_snapshot!)
      result
    ensure
      state.delete(:bean_collection_refreshes)
    end
  end

  def self.refresh_for_workspace(workspace_id)
    pending = ActiveSupport::IsolatedExecutionState[:bean_collection_refreshes]
    if pending
      pending.add(workspace_id)
    else
      find_by(workspace_id:)&.refresh_snapshot!
    end
  end

  def included_shares
    scope = eligible_shares.where.not(id: excluded_share_ids).where.not(beans: { coffee_history_id: excluded_history_ids })
    mode == "automatic" ? scope : scope.where(id: selected_share_ids)
  end

  def refresh_snapshot!
    return if destroyed?

    with_lock do
      update_columns(snapshot: PublicBeanCollectionSnapshotBuilder.new(collection: self).call, updated_at: Time.current)
    end
  end

  # Authorization queries only: public display content always comes from the stored snapshot.
  # Fail closed if an out-of-band update bypassed normal transactional refreshes.
  def public_snapshot
    payload = snapshot.deep_dup
    tokens = Array(payload["groups"]).flat_map { |group| Array(group["bags"]).map { |bag| bag["share_token"] } }.uniq
    if tokens.any? && included_shares.where(token: tokens).count != tokens.size
      payload["groups"] = []
    end
    brew_tokens = Array(payload["groups"]).flat_map { |group| Array(group["public_brews"]).map { |brew| brew["token"] } }.uniq
    allowed = workspace.public_brew_shares.where(token: brew_tokens, enabled: true, password_digest: nil).pluck(:token)
    Array(payload["groups"]).each do |group|
      group["public_brews"] = Array(group["public_brews"]).select { |brew| allowed.include?(brew["token"]) }
    end
    payload
  end

  private
    def prepare_settings
      self.token ||= SecureRandom.urlsafe_base64(24)
      self.token_digest = Digest::SHA256.hexdigest(token)
      %w[selected_share_ids excluded_share_ids representative_share_ids excluded_history_ids].each do |attribute|
        self[attribute] = Array(self[attribute]).reject(&:blank?).map { |value| Integer(value, exception: false) }.compact.uniq
      end
    end

    def selections_belong_to_workspace
      if workspace && workspace.coffee_histories.where(id: excluded_history_ids).count != excluded_history_ids.size
        errors.add(:base, "Excluded coffees must belong to this workspace")
      end
      ids = selected_share_ids | excluded_share_ids | representative_share_ids
      return if ids.empty? || workspace.blank?
      return if workspace.public_bean_shares.where(id: ids).count == ids.size

      errors.add(:base, "Selected bags must belong to this workspace")
    end

    def build_snapshot
      self.snapshot = PublicBeanCollectionSnapshotBuilder.new(collection: self).call
    end
end
