class EquipmentController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_equipment, only: :show

  def index
    @equipment = current_workspace.equipment.order(:kind, :name)
  end

  def show
    @recent_events = @equipment.equipment_events.includes(:user).recent.limit(5)
    @recent_brews = equipment_brews_scope.includes(:bean).order(occurred_at: :desc, created_at: :desc).limit(5)
    @last_service_event = last_service_event
    service_brews = @last_service_event ? equipment_brews_scope.where(occurred_at: @last_service_event.occurred_at..) : equipment_brews_scope
    @brews_since_service = service_brews.count
    @grams_since_service = service_brews.sum(:bean_weight_grams)
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

    def equipment_brews_scope
      @equipment.grinder? ? @equipment.grinder_brews : @equipment.machine_brews
    end

    def last_service_event
      event_types = if @equipment.grinder?
        %w[grinder_cleaning grinder_deep_cleaning burr_change]
      else
        %w[machine_descaling machine_backflush]
      end

      @equipment.equipment_events.recent.find { |event| (event.event_type_names & event_types).any? }
    end
end
