module SafeImageMedia
  extend ActiveSupport::Concern

  SAFE_IMAGE_CONTENT_TYPES = %w[
    image/gif
    image/jpeg
    image/png
    image/webp
  ].freeze

  private
    def ensure_safe_image_attachment!
      head :not_found unless safe_image_attachment?
    end

    def safe_image_attachment?(attachment = @attachment)
      attachment&.blob && SAFE_IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type.to_s.downcase)
    end

    def safe_image_content_type
      @attachment.blob.content_type.to_s.downcase
    end
end
