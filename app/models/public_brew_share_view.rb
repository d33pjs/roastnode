class PublicBrewShareView < ApplicationRecord
  RETAINED_ROWS_PER_SHARE = 100

  belongs_to :public_brew_share, counter_cache: :views_count
  belongs_to :workspace

  before_validation :set_workspace_from_share
  before_validation :set_viewed_at
  after_create_commit :prune_old_rows

  scope :recent, -> { order(viewed_at: :desc, id: :desc) }

  validates :ip_address, presence: true, length: { maximum: 255 }
  validates :user_agent, length: { maximum: 512 }, allow_blank: true
  validate :workspace_matches_share

  private
    def set_workspace_from_share
      self.workspace ||= public_brew_share&.workspace
    end

    def set_viewed_at
      self.viewed_at ||= Time.current
    end

    def workspace_matches_share
      return if workspace.blank? || public_brew_share.blank?
      return if workspace_id == public_brew_share.workspace_id

      errors.add(:workspace, "must match the public brew share workspace")
    end

    def prune_old_rows
      old_rows = public_brew_share.public_brew_share_views.recent.offset(RETAINED_ROWS_PER_SHARE).select(:id)
      public_brew_share.public_brew_share_views.where(id: old_rows).delete_all
    end
end
