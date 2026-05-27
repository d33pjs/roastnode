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

    if @inventory_adjustment.save_with_inventory_update
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
