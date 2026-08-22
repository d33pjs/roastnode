class PreparationToolsController < ApplicationController
  before_action :authorize_workspace_admin!, only: %i[new create edit update archive reopen destroy]
  before_action :set_preparation_tool, only: %i[show edit update archive reopen destroy]

  def index
    @preparation_tools = current_workspace.preparation_tools
      .includes(:primary_photo_record, photos_attachments: :blob)
      .ordered
  end

  def show
    @preparation_tool_statistics_start_date, @preparation_tool_statistics_end_date = preparation_tool_statistics_date_range
    @preparation_tool_statistics = PreparationToolStatistics.new(
      preparation_tool: @preparation_tool,
      start_date: @preparation_tool_statistics_start_date,
      end_date: @preparation_tool_statistics_end_date
    ).call
    @recent_brews = @preparation_tool_statistics[:recent_brews]
  end

  def new
    @preparation_tool = current_workspace.preparation_tools.new(brew_method: "espresso")
    prepare_record_links(@preparation_tool)
  end

  def edit
    prepare_record_links(@preparation_tool)
  end

  def create
    attributes = preparation_tool_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    @preparation_tool = current_workspace.preparation_tools.new(attributes)

    created = with_workspace_activity(action: "preparation_tool.created", subject: -> { @preparation_tool }) do
      saved = @preparation_tool.save
      @preparation_tool.photos.attach(photos) if saved && photos.any?
      refresh_public_brew_shares_for(@preparation_tool) if saved
      saved
    end

    if created
      redirect_to gear_path, notice: t(".created")
    else
      prepare_record_links(@preparation_tool)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = preparation_tool_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)

    updated = with_workspace_activity(action: "preparation_tool.updated", subject: @preparation_tool) do
      saved = @preparation_tool.update(attributes)
      @preparation_tool.photos.attach(photos) if saved && photos.any?
      refresh_public_brew_shares_for(@preparation_tool) if saved
      saved
    end

    if updated
      redirect_to gear_path, notice: t(".updated")
    else
      prepare_record_links(@preparation_tool)
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    with_workspace_activity(action: "preparation_tool.archived", subject: @preparation_tool) do
      @preparation_tool.archive!
      refresh_public_brew_shares_for(@preparation_tool)
      true
    end
    redirect_to gear_path, notice: t(".archived")
  end

  def reopen
    with_workspace_activity(action: "preparation_tool.reopened", subject: @preparation_tool) do
      @preparation_tool.reopen!
      refresh_public_brew_shares_for(@preparation_tool)
      true
    end
    redirect_to gear_path, notice: t(".reopened")
  end

  def destroy
    share_ids = PublicBrewShareRefresher.shares_for(@preparation_tool).pluck(:id)
    with_workspace_activity(action: "preparation_tool.deleted", subject: @preparation_tool) do
      @preparation_tool.destroy_with_history!
      refresh_public_brew_shares(share_ids)
      true
    end
    redirect_to gear_path, notice: t(".destroyed")
  end

  private
    def set_preparation_tool
      @preparation_tool = current_workspace.preparation_tools.find(params[:id])
    end

    def preparation_tool_statistics_date_range
      start_date = parse_preparation_tool_statistics_date(params[:start_date])
      end_date = parse_preparation_tool_statistics_date(params[:end_date])

      if start_date.present? && end_date.present? && start_date > end_date
        [ end_date, start_date ]
      else
        [ start_date, end_date ]
      end
    end

    def parse_preparation_tool_statistics_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def preparation_tool_params
      params.expect(preparation_tool: [
        :name,
        :brew_method,
        :notes,
        :position,
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

    def refresh_public_brew_shares_for(record)
      PublicBrewShareRefresher.refresh_for(record)
    end

    def refresh_public_brew_shares(share_ids)
      PublicBrewShare.where(id: share_ids).find_each { |share| PublicBrewShareRefresher.refresh(share) }
    end
end
