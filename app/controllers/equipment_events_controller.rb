class EquipmentEventsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update destroy]
  before_action :set_equipment_event, only: %i[show edit update destroy]

  def show
  end

  def new
    load_form_options
    @equipment_event = current_workspace.equipment_events.new(event_types: [ "grinder_cleaning" ], occurred_at: Time.current)
  end

  def edit
    load_form_options(selected_equipment: @equipment_event.equipment)
  end

  def create
    load_form_options
    attributes = equipment_event_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    equipment_ids = Array(attributes.delete(:equipment_ids)).reject(&:blank?)
    event_types = Array(attributes.delete(:event_types)).reject(&:blank?)
    @equipment_event = current_workspace.equipment_events.new(attributes.merge(event_types:, event_type: event_types.first))
    @equipment_event.user = Current.user
    @equipment_event.equipment = Equipment.where(id: equipment_ids)

    if @equipment_event.save
      @equipment_event.photos.attach(photos) if photos.any?
      redirect_to @equipment_event, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    load_form_options(selected_equipment: @equipment_event.equipment)
    attributes = equipment_event_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    equipment_ids = Array(attributes.delete(:equipment_ids)).reject(&:blank?)
    event_types = Array(attributes.delete(:event_types)).reject(&:blank?)

    @equipment_event.assign_attributes(attributes.merge(event_types:, event_type: event_types.first))
    @equipment_event.equipment = Equipment.where(id: equipment_ids)

    if @equipment_event.save
      @equipment_event.photos.attach(photos) if photos.any?
      redirect_to @equipment_event, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @equipment_event.destroy!
    redirect_to dashboard_path, notice: t(".destroyed")
  end

  private
    def set_equipment_event
      @equipment_event = current_workspace.equipment_events.includes(:equipment, :user).find(params[:id])
    end

    def load_form_options(selected_equipment: [])
      @equipment_options = current_workspace.equipment.active.order(:kind, :name).to_a
      Array(selected_equipment).each do |item|
        @equipment_options << item if item.workspace_id == current_workspace.id && @equipment_options.exclude?(item)
      end
      @equipment_options.sort_by! { |item| [ item.kind, item.name ] }
    end

    def equipment_event_params
      params.expect(equipment_event: [ :occurred_at, :notes, { event_types: [], equipment_ids: [], photos: [] } ])
    end
end
