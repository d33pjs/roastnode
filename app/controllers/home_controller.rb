class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    return unless authenticated?

    if current_workspace
      render "workspaces/show"
    else
      @workspace = Workspace.new(kind: :household, default_currency: "EUR")
      render "workspace_onboardings/new"
    end
  end
end
