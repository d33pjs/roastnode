class WorkspaceOnboardingsController < ApplicationController
  def new
    redirect_to root_path if current_workspace

    @workspace = Workspace.new(kind: :household, default_currency: "EUR")
  end

  def create
    @workspace = Workspace.new(workspace_params)
    @workspace.kind = :household
    @workspace.default_currency = "EUR"

    created = false
    Workspace.transaction do
      if @workspace.save
        membership = Current.user.memberships.create!(workspace: @workspace, role: :owner)
        Current.user.update!(active_workspace: membership.workspace)
        Activity::Emitter.record!(
          action: "workspace.created", workspace: @workspace, actor: Current.user, subject: @workspace
        )
        created = true
      end
    end

    if created
      redirect_to root_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def workspace_params
      params.require(:workspace).permit(:name)
    end
end
