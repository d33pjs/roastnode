class RecordLink < ApplicationRecord
  KINDS = %w[info buy affiliate].freeze
  VISIBILITIES = %w[private public].freeze

  belongs_to :workspace
  belongs_to :linkable, polymorphic: true

  scope :ordered, -> { order(:position, :created_at, :id) }
  scope :publicly_visible, -> { where(visibility: "public").ordered }

  before_validation :set_workspace_from_linkable

  validates :label, presence: true, length: { maximum: 120 }
  validates :url, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :url_is_http_or_https
  validate :linkable_belongs_to_workspace

  private
    def set_workspace_from_linkable
      self.workspace ||= linkable.workspace if linkable.respond_to?(:workspace)
    end

    def url_is_http_or_https
      uri = URI.parse(url.to_s)
      return if uri.is_a?(URI::HTTP) && uri.host.present?

      errors.add(:url, "must be an HTTP or HTTPS URL")
    rescue URI::InvalidURIError
      errors.add(:url, "must be an HTTP or HTTPS URL")
    end

    def linkable_belongs_to_workspace
      return if linkable.blank? || workspace.blank?
      return if linkable.respond_to?(:workspace_id) && linkable.workspace_id == workspace_id

      errors.add(:linkable, "must belong to the workspace")
    end
end
