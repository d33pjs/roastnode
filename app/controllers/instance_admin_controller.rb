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
  end
end
