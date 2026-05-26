class EquipmentController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update archive reopen destroy]
  before_action :set_equipment, only: %i[show edit update archive reopen destroy]

  def index
    @equipment = current_workspace.equipment
      .includes(:primary_photo_record, photos_attachments: :blob)
      .order(Arel.sql("archived_at ASC NULLS FIRST"), :kind, :name)
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

  def edit
  end

  def create
    attributes = equipment_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    @equipment = current_workspace.equipment.new(attributes)

    if @equipment.save
      @equipment.photos.attach(photos) if photos.any?
      redirect_to equipment_index_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = equipment_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)

    if @equipment.update(attributes)
      @equipment.photos.attach(photos) if photos.any?
      redirect_to @equipment, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @equipment.archive!
    redirect_to @equipment, notice: t(".archived")
  end

  def reopen
    @equipment.reopen!
    redirect_to @equipment, notice: t(".reopened")
  end

  def destroy
    @equipment.destroy_with_history!
    redirect_to equipment_index_path, notice: t(".destroyed")
  end

  private
    def set_equipment
      @equipment = current_workspace.equipment.find(params[:id])
    end

    def equipment_params
      params.expect(equipment: [ :name, :kind, :model, :notes, { photos: [] } ])
    end
end
