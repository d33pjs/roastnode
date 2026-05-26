class BrewPreparationTool < ApplicationRecord
  belongs_to :brew
  belongs_to :preparation_tool, optional: true

  validates :tool_name, presence: true
  validates :brew_method, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
