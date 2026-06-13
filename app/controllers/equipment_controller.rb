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
    @equipment = current_workspace.equipment.new(kind: params[:kind].presence_in(Equipment.kinds.keys) || "grinder")
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
      refresh_public_shares_for(@equipment)
      redirect_to gear_path, notice: t(".created")
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
      refresh_public_shares_for(@equipment)
      redirect_to gear_path, notice: t(".updated")
    else
      prepare_record_links(@equipment)
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @equipment.archive!
    refresh_public_shares_for(@equipment)
    redirect_to gear_path, notice: t(".archived")
  end

  def reopen
    @equipment.reopen!
    refresh_public_shares_for(@equipment)
    redirect_to gear_path, notice: t(".reopened")
  end

  def destroy
    public_brew_share_ids = PublicBrewShareRefresher.shares_for(@equipment).pluck(:id)
    public_bean_share_ids = PublicBeanShareRefresher.shares_for(@equipment).pluck(:id)
    @equipment.destroy_with_history!
    refresh_public_brew_shares(public_brew_share_ids)
    refresh_public_bean_shares(public_bean_share_ids)
    redirect_to gear_path, notice: t(".destroyed")
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
      params.expect(equipment: [
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
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def refresh_public_shares_for(record)
      PublicBrewShareRefresher.refresh_for(record)
      PublicBeanShareRefresher.refresh_for(record)
    end

    def refresh_public_brew_shares(share_ids)
      PublicBrewShare.where(id: share_ids).find_each { |share| PublicBrewShareRefresher.refresh(share) }
    end

    def refresh_public_bean_shares(share_ids)
      PublicBeanShare.where(id: share_ids).find_each { |share| PublicBeanShareRefresher.refresh(share) }
    end
end
