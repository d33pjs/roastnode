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
      return if session[unlock_session_key] == @share.password_unlock_fingerprint

      head :not_found
    end

    def set_attachment
      attachment_id = @share.public_attachment_id_for_media_handle(params[:media_id])
      return head :not_found if attachment_id.blank?

      @attachment = ActiveStorage::Attachment.find(attachment_id)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_attachment_public!
      head :not_found unless @attachment
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
      Rails.logger.info("Falling back to public thumbnail original #{public_attachment_log_id}: #{error.class}")
    end

    def public_attachment_log_id
      share_digest = Digest::SHA256.hexdigest(@share.id.to_s).first(12)
      attachment_digest = Digest::SHA256.hexdigest(@attachment.id.to_s).first(12)
      "PublicBrewShare##{share_digest}/attachment/#{attachment_digest}"
    end

    def public_filename
      params[:variant] == THUMBNAIL_VARIANT ? "public-brew-thumbnail" : "public-brew-media"
    end

    def unlock_session_key
      "public_brew_share:#{@share.token}:unlocked"
    end
end
