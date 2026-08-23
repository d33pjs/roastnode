class PublicBrewMediaController < ApplicationController
  include SafeImageMedia

  THUMBNAIL_VARIANT = MediaAttachmentsController::THUMBNAIL_VARIANT
  THUMBNAIL_TRANSFORMATIONS = MediaAttachmentsController::THUMBNAIL_TRANSFORMATIONS
  HERO_VARIANT = MediaAttachmentsController::HERO_VARIANT
  HERO_TRANSFORMATIONS = MediaAttachmentsController::HERO_TRANSFORMATIONS
  MEDIA_VARIANTS = MediaAttachmentsController::MEDIA_VARIANTS

  allow_unauthenticated_access

  before_action :set_share
  before_action :ensure_share_unlocked!
  before_action :set_attachment
  before_action :ensure_attachment_public!
  before_action :ensure_safe_image_attachment!

  def show
    return send_blob(disposition: "inline") if params[:variant].blank?

    transformations = MEDIA_VARIANTS[params[:variant]]
    return head :not_found unless transformations

    send_variant(params[:variant], transformations)
  end

  private
    def set_share
      @share = PublicBrewShare.find_enabled_by_token!(params[:token])
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
        type: safe_image_content_type,
        disposition:,
        filename: public_filename
    end

    def send_variant(name, transformations)
      return head :not_found unless safe_image_attachment? && @attachment.blob.image?

      data = variant_data(transformations, name)
      return head :not_found if data.nil?

      response.set_header("X-Roastnode-Media-Variant", name)
      send_blob(
        disposition: "inline",
        data:
      )
    end

    def variant_data(transformations, name)
      @attachment.blob.variant(transformations).processed.download
    rescue LoadError => error
      variant_failure_data(name, error)
    rescue => error
      variant_failure_data(name, error)
    end

    def variant_failure_data(name, error)
      if name == HERO_VARIANT
        Rails.logger.info("Rejecting failed public hero media processing for #{public_attachment_log_id}: #{error.class}")
        return
      end

      log_variant_fallback(name, error)
      @attachment.blob.download
    end

    def log_variant_fallback(name, error)
      Rails.logger.info("Falling back to public #{name} original #{public_attachment_log_id}: #{error.class}")
    end

    def public_attachment_log_id
      share_digest = Digest::SHA256.hexdigest(@share.id.to_s).first(12)
      attachment_digest = Digest::SHA256.hexdigest(@attachment.id.to_s).first(12)
      "PublicBrewShare##{share_digest}/attachment/#{attachment_digest}"
    end

    def public_filename
      case params[:variant]
      when THUMBNAIL_VARIANT then "public-brew-thumbnail"
      when HERO_VARIANT then "public-brew-hero"
      else "public-brew-media"
      end
    end

    def unlock_session_key
      "public_brew_share:#{@share.token}:unlocked"
    end
end
