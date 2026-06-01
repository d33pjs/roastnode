class EquipmentController < ApplicationController
  before_action :authorize_workspace_admin!, only: %i[new create edit update archive reopen destroy]
  before_action :set_equipment, only: %i[show edit update archive reopen destroy]

  def index
    @equipment = current_workspace.equipment
      .includes(:primary_photo_record, photos_attachments: :blob)
      .order(Arel.sql("archived_at ASC NULLS FIRST"), :kind, :name)
  end

  def show
    @equipment_statistics_start_date, @equipment_statistics_end_date = equipment_statistics_date_range
    @equipment_statistics = EquipmentStatistics.new(
      equipment: @equipment,
      start_date: @equipment_statistics_start_date,
      end_date: @equipment_statistics_end_date
    ).call
    @recent_events = @equipment_statistics[:recent_events]
    @recent_brews = @equipment_statistics[:recent_brews]
    @last_service_event = @equipment_statistics[:service][:last_event]
  end

  def new
    @equipment = current_workspace.equipment.new(kind: "grinder")
    prepare_record_links(@equipment)
  end

  def edit
    prepare_record_links(@equipment)
  end

  def create
    attributes = equipment_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    @equipment = current_workspace.equipment.new(attributes)

    if @equipment.save
      @equipment.photos.attach(photos) if photos.any?
      redirect_to equipment_index_path, notice: t(".created")
    else
      prepare_record_links(@equipment)
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
      prepare_record_links(@equipment)
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

    def equipment_statistics_date_range
      start_date = parse_equipment_statistics_date(params[:start_date])
      end_date = parse_equipment_statistics_date(params[:end_date])

      if start_date.present? && end_date.present? && start_date > end_date
        [ end_date, start_date ]
      else
        [ start_date, end_date ]
      end
    end

    def parse_equipment_statistics_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def equipment_params
      attributes = params.expect(equipment: [
        :name,
        :kind,
        :model,
        :notes,
        :public_note,
        {
          photos: [],
          record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
        }
      ])
      reject_blank_record_link_attributes(attributes)
    end

    def prepare_record_links(record)
      blank_rows = 3 - record.record_links.reject(&:marked_for_destruction?).size
      record.build_blank_record_links(blank_rows) if blank_rows.positive?
    end

    def reject_blank_record_link_attributes(attributes)
      attributes[:record_links_attributes]&.delete_if do |_index, link_attributes|
        link_attributes[:label].blank? && link_attributes["label"].blank? &&
          link_attributes[:url].blank? && link_attributes["url"].blank?
      end
      attributes
    end
end
