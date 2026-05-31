class PasskeyCredential < ApplicationRecord
  belongs_to :user

  normalizes :nickname, with: ->(nickname) { nickname.strip.presence }

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def display_name
    return nickname if nickname.present?
    return "Passkey added #{created_at.to_date.to_fs(:long)}" if created_at.present?

    "Passkey"
  end
end
