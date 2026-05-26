class EquipmentEventsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_equipment_event, only: :show

  def show
  end

  def new
    load_form_options
    @equipment_event = current_workspace.equipment_events.new(event_types: [ "grinder_cleaning" ], occurred_at: Time.current)
  end

  def create
    load_form_options
    attributes = equipment_event_params
    equipment_ids = Array(attributes.delete(:equipment_ids)).reject(&:blank?)
    event_types = Array(attributes.delete(:event_types)).reject(&:blank?)
    @equipment_event = current_workspace.equipment_events.new(attributes.merge(event_types:, event_type: event_types.first))
    @equipment_event.user = Current.user
    @equipment_event.equipment = Equipment.where(id: equipment_ids)

    if @equipment_event.save
      redirect_to @equipment_event, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_equipment_event
      @equipment_event = current_workspace.equipment_events.includes(:equipment, :user).find(params[:id])
    end

    def load_form_options
      @equipment_options = current_workspace.equipment.order(:kind, :name)
    end

    def equipment_event_params
      params.expect(equipment_event: [ :occurred_at, :notes, { event_types: [], equipment_ids: [] } ])
    end
end
