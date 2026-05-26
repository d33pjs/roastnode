class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :created_workspace_invites, class_name: "WorkspaceInvite", foreign_key: :created_by_id, dependent: :destroy,
    inverse_of: :created_by
  has_many :accepted_workspace_invites, class_name: "WorkspaceInvite", foreign_key: :accepted_by_id, dependent: :nullify,
    inverse_of: :accepted_by
  has_many :brews, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception

  belongs_to :active_workspace, class_name: "Workspace", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def membership_for(workspace)
    memberships.find_by(workspace:)
  end

  def ensure_active_workspace!
    return active_workspace if active_workspace.present? && memberships.exists?(workspace: active_workspace)

    update!(active_workspace: workspaces.first)
    active_workspace
  end
end
