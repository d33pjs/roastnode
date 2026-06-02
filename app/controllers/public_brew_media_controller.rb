class PublicBrewMediaController < ApplicationController
  THUMBNAIL_VARIANT = MediaAttachmentsController::THUMBNAIL_VARIANT
  THUMBNAIL_TRANSFORMATIONS = MediaAttachmentsController::THUMBNAIL_TRANSFORMATIONS

  allow_unauthenticated_access

  before_action :set_share
  before_action :ensure_share_unlocked!
  before_action :set_attachment
  before_action :ensure_attachment_public!

  def show
    return send_thumbnail if params[:variant] == THUMBNAIL_VARIANT
    return head :not_found if params[:variant].present?

    send_blob(disposition: "inline")
  end

  private
    def set_share
      @share = PublicBrewShare.find_by!(token: params[:token], enabled: true)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_share_unlocked!
      return unless @share&.password_protected?
      return if session[unlock_session_key]

      head :not_found
    end

    def set_attachment
      @attachment = ActiveStorage::Attachment.find(params[:attachment_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_attachment_public!
      head :not_found unless @attachment && @share.public_attachment_ids.include?(@attachment.id)
    end

    def send_blob(disposition:, data: @attachment.blob.download)
      send_data data,
        type: @attachment.blob.content_type,
        disposition:,
        filename: public_filename
    end

    def send_thumbnail
      return head :not_found unless @attachment.blob.image?

      response.set_header("X-Roastnode-Media-Variant", THUMBNAIL_VARIANT)
      send_blob(
        disposition: "inline",
        data: thumbnail_data
      )
    end

    def thumbnail_data
      @attachment.blob.variant(THUMBNAIL_TRANSFORMATIONS).processed.download
    rescue LoadError => error
      log_thumbnail_fallback(error)
      @attachment.blob.download
    rescue => error
      log_thumbnail_fallback(error)
      @attachment.blob.download
    end

    def log_thumbnail_fallback(error)
      Rails.logger.info("Falling back to public thumbnail original #{public_attachment_log_id}: #{error.class}: #{error.message}")
    end

    def public_attachment_log_id
      "PublicBrewShare##{@share.token}/attachment/#{@attachment.id}"
    end

    def public_filename
      "#{params[:variant] == THUMBNAIL_VARIANT ? "thumbnail-" : ""}public-brew-media-#{@attachment.id}"
    end

    def unlock_session_key
      "public_brew_share:#{@share.token}:unlocked"
    end
end
