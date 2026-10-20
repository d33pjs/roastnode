class GrinderUsesController < ApplicationController
  before_action :authorize_workspace_write!

  def create
    response.headers["Cache-Control"] = "private, no-store"
    attributes = params.require(:grinder_use).permit(:bean_id, :grinder_id, :method, :grind_setting, :confirmation_key)
    candidate = current_workspace.grinder_uses.new(
      user: Current.user,
      bean: current_workspace.beans.find(attributes[:bean_id]),
      grinder: current_workspace.equipment.find(attributes[:grinder_id]),
      method: attributes[:method], grind_setting: attributes[:grind_setting], confirmation_key: attributes[:confirmation_key]
    )

    # Serialize confirmations for this operator so simultaneous retries return the
    # same event without racing the unique key or changing its occurrence time.
    Current.user.with_lock do
      use = current_workspace.grinder_uses.find_by(user: Current.user, confirmation_key: candidate.confirmation_key)
      if use && !use.matches_brew?(candidate)
        render json: { errors: [ "This confirmation belongs to a different preparation." ] }, status: :unprocessable_entity
      elsif use || candidate.save
        render_use(use || candidate, status: use ? :ok : :created)
      else
        render json: { errors: candidate.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  private
    def render_use(use, status:)
      reminder = BrewGrinderReminder.new(workspace: current_workspace, user: Current.user, method: use.method, beans: []).call
      render json: {
        use: { id: use.id, occurred_at: use.occurred_at.iso8601(6), bean_id: use.bean_id,
          grinder_id: use.grinder_id, method: use.method, grind_setting: use.grind_setting },
        last_uses: helpers.brew_grinder_last_uses(reminder)
      }, status:
    end
end
