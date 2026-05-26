class PreparationTool < ApplicationRecord
  include HasPrimaryPhoto

  belongs_to :workspace
  belongs_to :data_import, optional: true

  has_many :brew_preparation_tools, dependent: :nullify
  has_many :brews, through: :brew_preparation_tools
  has_many_attached :photos

  before_validation :set_defaults
  before_validation :assign_default_position, on: :create

  scope :active, -> { where(active: true) }
  scope :espresso, -> { where(brew_method: "espresso") }
  scope :ordered, -> { order(active: :desc, position: :asc, name: :asc) }

  validates :name, presence: true
  validates :brew_method, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true

  def archive!
    update!(active: false)
  end

  def reopen!
    update!(active: true)
  end

  private
    def set_defaults
      self.brew_method ||= "espresso"
      self.active = true if active.nil?
    end

    def assign_default_position
      return if position.present? && position.positive?
      return unless workspace

      self.position = workspace.preparation_tools.active.maximum(:position).to_i + 10
    end
end
