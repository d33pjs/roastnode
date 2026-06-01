class WorkspaceActivityFeed
  def initialize(workspace)
    @workspace = workspace
  end

  def records
    @records ||= (brews + manual_adjustments + equipment_events).sort_by do |record|
      [ record.occurred_at || Time.zone.at(0), record.created_at || Time.zone.at(0) ]
    end.reverse
  end

  private
    attr_reader :workspace

    def brews
      workspace.brews.includes(:bean, :user).to_a
    end

    def manual_adjustments
      workspace.inventory_adjustments.manual.includes(:bean, :user).to_a
    end

    def equipment_events
      workspace.equipment_events.includes(:equipment, :user).to_a
    end
end
