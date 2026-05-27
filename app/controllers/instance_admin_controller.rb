class InstanceAdminController < ApplicationController
  before_action :authorize_instance_admin!

  def index
    @metrics = {
      users: User.count,
      workspaces: Workspace.count,
      beans: Bean.count,
      brews: Brew.count,
      equipment: Equipment.count
    }
    @health_checks = InstanceHealthSnapshot.new.checks
    @user_rows = InstanceUserSnapshot.new.rows
    @backup_profiles = InstanceBackupProfile.includes(:instance_backup_runs).order(:backup_kind, :id)
    @backup_runs = InstanceBackupRun.includes(:instance_backup_profile).order(created_at: :desc).limit(8)
  end
end
