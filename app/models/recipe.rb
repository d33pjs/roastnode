class Recipe < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  enum :method, {
    espresso: "espresso"
  }

  belongs_to :workspace
  belongs_to :created_by, class_name: "User"
  belongs_to :source_brew, class_name: "Brew", optional: true

  has_many :brews, dependent: :nullify
  has_one :public_recipe_share, dependent: :destroy
  has_many_attached :photos

  before_validation :set_defaults

  validates :title, presence: true, length: { maximum: 160 }
  validates :profile, presence: true
  validates :source_snapshot, presence: true
  validate :source_brew_belongs_to_workspace
  validate :created_by_belongs_to_workspace

  def export_filename
    suffix = id ? id.to_s(36) : "new"
    "#{title.to_s.parameterize.presence || "recipe"}-#{suffix}.json"
  end

  private
    def set_defaults
      self.method ||= "espresso"
      self.profile ||= {}
      self.source_snapshot ||= {}
    end

    def source_brew_belongs_to_workspace
      return if source_brew.blank? || workspace.blank? || source_brew.workspace_id == workspace_id

      errors.add(:source_brew, "must belong to the workspace")
    end

    def created_by_belongs_to_workspace
      return if created_by.blank? || workspace.blank?
      return if created_by.memberships.exists?(workspace:)

      errors.add(:created_by, "must belong to the workspace")
    end
end
