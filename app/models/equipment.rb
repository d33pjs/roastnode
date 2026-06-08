class Equipment < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  enum :kind, {
    grinder: "grinder",
    machine: "machine",
    brewer: "brewer"
  }

  belongs_to :workspace
  belongs_to :data_import, optional: true

  has_many :grinder_brews, class_name: "Brew", foreign_key: :grinder_id, dependent: :nullify, inverse_of: :grinder
  has_many :machine_brews, class_name: "Brew", foreign_key: :machine_id, dependent: :nullify, inverse_of: :machine
  has_many :brewer_brews, class_name: "Brew", foreign_key: :brewer_id, dependent: :nullify, inverse_of: :brewer
  has_many :equipment_event_items, dependent: :destroy
  has_many :equipment_events, through: :equipment_event_items
  has_many_attached :photos

  scope :active, -> { where(archived_at: nil) }

  validates :name, presence: true
  validates :kind, presence: true
  validates :import_source_id, uniqueness: { scope: %i[workspace_id import_source] }, allow_blank: true

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def reopen!
    update!(archived_at: nil)
  end

  def destroy_with_history!
    transaction do
      grinder_brews.update_all(grinder_id: nil)
      machine_brews.update_all(machine_id: nil)
      brewer_brews.update_all(brewer_id: nil)
      destroy!
    end
  end
end
