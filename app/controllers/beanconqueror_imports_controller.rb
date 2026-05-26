class BeanconquerorImportsController < ApplicationController
  before_action :authorize_workspace_admin!
  before_action :set_data_import, only: :show

  def new
  end

  def create
    uploaded_file = params.dig(:beanconqueror_import, :file)

    if uploaded_file.blank?
      redirect_to new_beanconqueror_import_path, alert: t(".missing_file")
      return
    end

    data_import = BeanconquerorImport.new(
      workspace: current_workspace,
      user: Current.user,
      json: uploaded_file.read
    ).call

    redirect_to beanconqueror_import_path(data_import), notice: t(".created")
  end

  def show
  end

  private
    def set_data_import
      @data_import = current_workspace.data_imports.find(params[:id])
    end
end
