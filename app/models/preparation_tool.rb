class PreparationTool < ApplicationRecord
  belongs_to :workspace
  belongs_to :data_import, optional: true

  has_many :brew_preparation_tools, dependent: :nullify
  has_many :brews, through: :brew_preparation_tools

  before_validation :set_defaults

  scope :active, -> { where(active: true) }
  scope :espresso, -> { where(brew_method: "espresso") }
  scope :ordered, -> { order(:name) }

  validates :name, presence: true
  validates :brew_method, presence: true
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true

  private
    def set_defaults
      self.brew_method ||= "espresso"
      self.active = true if active.nil?
    end
end
