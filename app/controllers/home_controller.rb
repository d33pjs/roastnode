class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    return unless authenticated?

    if current_workspace && Current.user.default_landing_log_espresso?
      return redirect_to new_brew_path
    end

    render_dashboard
  end

  def dashboard
    return redirect_to root_path unless authenticated?

    render_dashboard
  end

  private
    def render_dashboard
      if current_workspace
        load_dashboard
        render "workspaces/show"
      else
        @workspace = Workspace.new(kind: :household, default_currency: "EUR")
        render "workspace_onboardings/new"
      end
    end

    def load_dashboard
      @dashboard_metrics = DashboardMetrics.new(workspace: current_workspace).call
      @open_bean_cockpit_entries = OpenBeanCockpit.new(workspace: current_workspace).call
      @stock_bean_shelf_entries = StockBeanShelf.new(workspace: current_workspace).call
      @open_beans = @open_bean_cockpit_entries.map(&:bean)
      @latest_coffee = latest_dashboard_coffee
      @latest_best_brew = dashboard_brews.where.not(rating: nil).order(rating: :desc, occurred_at: :desc, created_at: :desc).first
      @recent_activity = WorkspaceActivityFeed.new(current_workspace).records(limit: 8)
    end

    def dashboard_brews
      current_workspace.brews.includes(:bean, :user, :grinder, :machine, :brew_preparation_tools)
    end

    def dashboard_external_coffees
      current_workspace.external_coffees.includes(:user, :primary_photo_record, photos_attachments: :blob)
    end

    def latest_dashboard_coffee
      (dashboard_brews.order(occurred_at: :desc, created_at: :desc).limit(1).to_a +
        dashboard_external_coffees.order(occurred_at: :desc, created_at: :desc).limit(1).to_a)
        .max_by { |record| [ record.occurred_at || Time.at(0), record.created_at || Time.at(0) ] }
    end
end
