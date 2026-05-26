class WorkspaceExportsController < ApplicationController
  before_action :authorize_workspace_export!

  def show
    payload = WorkspaceExportBuilder.new(current_workspace).call

    send_data JSON.pretty_generate(payload),
      filename: "#{current_workspace.name.parameterize}-export.json",
      type: "application/json",
      disposition: "attachment"
  end
end
