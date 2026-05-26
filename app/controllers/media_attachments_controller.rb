class MediaAttachmentsController < ApplicationController
  before_action :set_attachment
  before_action :ensure_attachment_in_current_workspace!

  def show
    send_data @attachment.blob.download,
      type: @attachment.blob.content_type,
      disposition: "inline",
      filename: @attachment.blob.filename.to_s
  end

  def download
    send_data @attachment.blob.download,
      type: @attachment.blob.content_type,
      disposition: "attachment",
      filename: @attachment.blob.filename.to_s
  end

  def destroy
    unless current_workspace_policy.write?
      redirect_to root_path, alert: t("authorization.denied")
      return
    end

    record = @attachment.record
    @attachment.destroy!

    redirect_back_or_to record_path(record), notice: t(".destroyed")
  end

  private
    def set_attachment
      @attachment = ActiveStorage::Attachment.find(params[:id])
    end

    def ensure_attachment_in_current_workspace!
      head :not_found unless attachment_in_current_workspace?(@attachment)
    end

    def attachment_in_current_workspace?(attachment)
      record = attachment.record

      record.respond_to?(:workspace_id) && record.workspace_id == current_workspace&.id
    end

    def record_path(record)
      case record
      when Bean
        bean_path(record)
      when Brew
        brew_path(record)
      when Equipment
        equipment_path(record)
      when EquipmentEvent
        equipment_event_path(record)
      else
        root_path
      end
    end
end
