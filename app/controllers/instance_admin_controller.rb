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
  end
end
