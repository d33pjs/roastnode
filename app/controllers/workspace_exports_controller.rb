class WorkspaceExportsController < ApplicationController
  before_action :authorize_workspace_export!

  def show
    payload = WorkspaceExportBuilder.new(current_workspace).call

    send_data JSON.pretty_generate(payload),
      filename: "#{current_workspace.name.parameterize}-export.json",
      type: "application/json",
      disposition: "attachment"
  end

  def beans
    send_data csv_export.beans_csv,
      filename: "#{current_workspace.name.parameterize}-beans.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def brews
    send_data csv_export.brews_csv,
      filename: "#{current_workspace.name.parameterize}-brews.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  private
    def csv_export
      @csv_export ||= WorkspaceCsvExportBuilder.new(current_workspace)
    end
end
