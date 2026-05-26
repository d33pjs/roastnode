class Membership < ApplicationRecord
  enum :role, {
    owner: "owner",
    admin: "admin",
    member: "member",
    viewer: "viewer"
  }

  belongs_to :user
  belongs_to :workspace

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :workspace_id }

  def can_manage_workspace?
    owner? || admin?
  end

  def can_write_workspace_data?
    owner? || admin? || member?
  end
end

