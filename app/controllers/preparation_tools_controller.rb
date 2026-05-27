class PreparationToolsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update archive reopen destroy]
  before_action :set_preparation_tool, only: %i[show edit update archive reopen destroy]

  def index
    @preparation_tools = current_workspace.preparation_tools.ordered
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
  end

  def edit
  end

  def create
    attributes = preparation_tool_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    @preparation_tool = current_workspace.preparation_tools.new(attributes)

    if @preparation_tool.save
      @preparation_tool.photos.attach(photos) if photos.any?
      redirect_to preparation_tools_path, notice: t(".created")
    else
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
      params.expect(preparation_tool: [ :name, :brew_method, :notes, :position, { photos: [] } ])
    end
end
