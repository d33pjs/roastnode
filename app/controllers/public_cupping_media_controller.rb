require "digest"

class PublicCuppingMediaController < ApplicationController
  include SafeImageMedia

  THUMBNAIL_VARIANT = MediaAttachmentsController::THUMBNAIL_VARIANT
  THUMBNAIL_TRANSFORMATIONS = MediaAttachmentsController::THUMBNAIL_TRANSFORMATIONS

  allow_unauthenticated_access

  before_action :set_cupping_request
  before_action :set_attachment
  before_action :ensure_attachment_public!
  before_action :ensure_safe_image_attachment!

  def show
    return send_thumbnail if params[:variant] == THUMBNAIL_VARIANT
    return head :not_found if params[:variant].present?

    send_blob
  end

  private
    def set_cupping_request
      @cupping_request = CuppingRequest.find_by_token!(params[:token])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_attachment
      attachment_id = @cupping_request.public_attachment_id_for_media_handle(params[:media_id])
      return head :not_found if attachment_id.blank?

      @attachment = ActiveStorage::Attachment.find(attachment_id)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_attachment_public!
      head :not_found unless @attachment
    end

    def send_blob(data: @attachment.blob.download)
      send_data data,
        type: safe_image_content_type,
        disposition: "inline",
        filename: public_filename
    end

    def send_thumbnail
      return head :not_found unless safe_image_attachment? && @attachment.blob.image?

      response.set_header("X-Roastnode-Media-Variant", THUMBNAIL_VARIANT)
      send_blob(data: thumbnail_data)
    end

    def thumbnail_data
      @attachment.blob.variant(THUMBNAIL_TRANSFORMATIONS).processed.download
    rescue LoadError, StandardError => error
      Rails.logger.info("Falling back to public cupping thumbnail original #{public_attachment_log_id}: #{error.class}")
      @attachment.blob.download
    end

    def public_attachment_log_id
      request_digest = Digest::SHA256.hexdigest(@cupping_request.id.to_s).first(12)
      attachment_digest = Digest::SHA256.hexdigest(@attachment.id.to_s).first(12)
      "CuppingRequest##{request_digest}/attachment/#{attachment_digest}"
    end

    def public_filename
      params[:variant] == THUMBNAIL_VARIANT ? "public-cupping-thumbnail" : "public-cupping-media"
    end
end
