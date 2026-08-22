class WorkspaceExportsController < ApplicationController
  before_action :authorize_workspace_export!

  def show
    payload = audited_export("json") { JSON.pretty_generate(WorkspaceExportBuilder.new(current_workspace).call) }

    send_data payload,
      filename: "#{current_workspace.name.parameterize}-export.json",
      type: "application/json",
      disposition: "attachment"
  end

  def beans
    payload = audited_export("beans_csv") { csv_export.beans_csv }

    send_data payload,
      filename: "#{current_workspace.name.parameterize}-beans.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def brews
    payload = audited_export("brews_csv") { csv_export.brews_csv }

    send_data payload,
      filename: "#{current_workspace.name.parameterize}-brews.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def external_coffees
    payload = audited_export("external_coffees_csv") { csv_export.external_coffees_csv }

    send_data payload,
      filename: "#{current_workspace.name.parameterize}-external-coffees.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def media
    payload = audited_export("media_zip") { WorkspaceMediaArchiveBuilder.new(current_workspace).call }

    send_data payload,
      filename: "#{current_workspace.name.parameterize}-media.zip",
      type: "application/zip",
      disposition: "attachment"
  end

  private
    def audited_export(export_kind)
      artifact = yield
      record_export!(export_kind)
      artifact
    end

    def record_export!(export_kind)
      Activity::Emitter.record!(
        action: "workspace_export.generated", workspace: current_workspace,
        actor: Current.user, subject: current_workspace, details: { export_kind: }
      )
    end

    def csv_export
      @csv_export ||= WorkspaceCsvExportBuilder.new(current_workspace)
    end
end
