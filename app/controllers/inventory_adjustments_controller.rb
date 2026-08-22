class InventoryAdjustmentsController < ApplicationController
  before_action :authorize_workspace_write!
  before_action :set_bean

  def new
    @inventory_adjustment = @bean.inventory_adjustments.new(
      workspace: current_workspace,
      user: Current.user,
      reason: "manual",
      occurred_at: Time.current
    )
  end

  def create
    @inventory_adjustment = @bean.inventory_adjustments.new(inventory_adjustment_params)
    @inventory_adjustment.workspace = current_workspace
    @inventory_adjustment.user = Current.user
    @inventory_adjustment.reason = "manual"

    previous_status = @bean.bag_status
    created = false
    ActiveRecord::Base.transaction do
      created = @inventory_adjustment.save_with_inventory_update
      raise ActiveRecord::Rollback unless created

      Activity::Emitter.record!(
        action: "inventory_adjustment.created",
        workspace: current_workspace,
        actor: Current.user,
        subject: @inventory_adjustment,
        occurred_at: @inventory_adjustment.occurred_at
      )
      record_used_up_transition!(@bean, previous_status:)
    end

    if created
      redirect_to @bean, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    DECIMAL_INVENTORY_ADJUSTMENT_FIELDS = %i[delta_grams].freeze

    def set_bean
      @bean = current_workspace.beans.find(params[:bean_id])
    end

    def inventory_adjustment_params
      normalize_decimal_attributes(params.expect(inventory_adjustment: [
        :delta_grams,
        :occurred_at,
        :note
      ]), *DECIMAL_INVENTORY_ADJUSTMENT_FIELDS)
    end
end
