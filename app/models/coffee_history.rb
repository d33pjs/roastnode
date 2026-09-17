class CoffeeHistory < ApplicationRecord
  belongs_to :workspace
  has_many :beans, dependent: :restrict_with_exception
end
