class DataImport < ApplicationRecord
  enum :status, {
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }

  belongs_to :workspace
  belongs_to :user

  has_many :beans, dependent: :nullify
  has_many :equipment, dependent: :nullify
  has_many :preparation_tools, dependent: :nullify
  has_many :brews, dependent: :nullify

  validates :source, presence: true
  validates :status, presence: true
end
