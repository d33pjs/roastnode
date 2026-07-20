class WorkspaceActivityFeed
  def initialize(workspace)
    @workspace = workspace
  end

  def records(limit: nil)
    records = (brews(limit:) + external_coffees(limit:) + manual_adjustments(limit:) + equipment_events(limit:)).sort_by do |record|
      [ record.occurred_at || Time.zone.at(0), record.created_at || Time.zone.at(0) ]
    end.reverse

    limit ? records.first(limit) : records
  end

  private
    attr_reader :workspace

    def brews(limit:)
      apply_limit(workspace.brews.includes(:bean, :user).order(occurred_at: :desc, created_at: :desc), limit).to_a
    end

    def external_coffees(limit:)
      apply_limit(workspace.external_coffees.includes(:user).order(occurred_at: :desc, created_at: :desc), limit).to_a
    end

    def manual_adjustments(limit:)
      apply_limit(
        workspace.inventory_adjustments.manual.includes(:bean, :user).order(occurred_at: :desc, created_at: :desc),
        limit
      ).to_a
    end

    def equipment_events(limit:)
      apply_limit(workspace.equipment_events.includes(:equipment, :user).recent, limit).to_a
    end

    def apply_limit(scope, limit)
      limit ? scope.limit(limit) : scope
    end
end
