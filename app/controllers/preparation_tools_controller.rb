class PreparationToolsController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]

  def index
    @preparation_tools = current_workspace.preparation_tools.ordered
  end

  def new
    @preparation_tool = current_workspace.preparation_tools.new(brew_method: "espresso")
  end

  def create
    @preparation_tool = current_workspace.preparation_tools.new(preparation_tool_params)

    if @preparation_tool.save
      redirect_to preparation_tools_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def preparation_tool_params
      params.expect(preparation_tool: [ :name, :brew_method, :notes, { photos: [] } ])
    end
end
