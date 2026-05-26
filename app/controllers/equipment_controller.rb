class EquipmentController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_equipment, only: :show

  def index
    @equipment = current_workspace.equipment.order(:kind, :name)
  end

  def show
    @equipment_statistics = EquipmentStatistics.new(equipment: @equipment).call
    @recent_events = @equipment_statistics[:recent_events]
    @recent_brews = @equipment_statistics[:recent_brews]
    @last_service_event = @equipment_statistics[:service][:last_event]
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
    def set_equipment
      @equipment = current_workspace.equipment.find(params[:id])
    end

    def equipment_params
      params.expect(equipment: [ :name, :kind, :model, :notes, { photos: [] } ])
    end
end
