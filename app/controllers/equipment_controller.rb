class EquipmentController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]

  def index
    @equipment = current_workspace.equipment.order(:kind, :name)
  end

  def new
    @equipment = current_workspace.equipment.new(kind: "grinder")
  end

  def create
    @equipment = current_workspace.equipment.new(equipment_params)

    if @equipment.save
      redirect_to equipment_index_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def equipment_params
      params.expect(equipment: [ :name, :kind, :model, :notes ])
    end
end
