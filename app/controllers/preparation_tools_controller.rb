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

    if @preparation_tool.save
      @preparation_tool.photos.attach(photos) if photos.any?
      redirect_to preparation_tools_path, notice: t(".created")
    else
      prepare_record_links(@preparation_tool)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = preparation_tool_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)

    if @preparation_tool.update(attributes)
      @preparation_tool.photos.attach(photos) if photos.any?
      redirect_to @preparation_tool, notice: t(".updated")
    else
      prepare_record_links(@preparation_tool)
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @preparation_tool.archive!
    redirect_to @preparation_tool, notice: t(".archived")
  end

  def reopen
    @preparation_tool.reopen!
    redirect_to @preparation_tool, notice: t(".reopened")
  end

  def destroy
    @preparation_tool.destroy_with_history!
    redirect_to preparation_tools_path, notice: t(".destroyed")
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
      attributes = params.expect(preparation_tool: [
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
