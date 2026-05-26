class MediaAttachmentsController < ApplicationController
  def show
    attachment = ActiveStorage::Attachment.find(params[:id])
    return head :not_found unless attachment_in_current_workspace?(attachment)

    send_data attachment.blob.download,
      type: attachment.blob.content_type,
      disposition: "inline",
      filename: attachment.blob.filename.to_s
  end

  private
    def attachment_in_current_workspace?(attachment)
      record = attachment.record

      record.respond_to?(:workspace_id) && record.workspace_id == current_workspace&.id
    end
end
