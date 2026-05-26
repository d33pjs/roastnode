class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    return unless authenticated?

    if current_workspace
      load_dashboard
      render "workspaces/show"
    else
      @workspace = Workspace.new(kind: :household, default_currency: "EUR")
      render "workspace_onboardings/new"
    end
  end

  private
    def load_dashboard
      @open_beans = current_workspace.beans.open.limit(5)
      @brews_this_week = current_workspace.brews.where(occurred_at: Time.current.all_week).count
      @open_bean_count = current_workspace.beans.open.count
      @grams_remaining = current_workspace.beans.open.sum(:remaining_grams)
      @recent_brews = current_workspace.brews.includes(:bean, :user).order(occurred_at: :desc, created_at: :desc).limit(5)
      @recent_adjustments = current_workspace.inventory_adjustments.manual.includes(:bean, :user).order(occurred_at: :desc, created_at: :desc).limit(5)
      @recent_equipment_events = current_workspace.equipment_events.includes(:equipment, :user).recent.limit(5)
      @recent_activity = (@recent_brews.to_a + @recent_adjustments.to_a + @recent_equipment_events.to_a).sort_by(&:occurred_at).reverse.first(8)
    end
end
