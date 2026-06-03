class RecipeExporter
  SCHEMA = "roastnode.recipe"
  VERSION = 1
  MEDIA_PATH_MARKERS = [
    "/rails/active_storage",
    "/media_attachments"
  ].freeze
  PUBLIC_MEDIA_PATH_PATTERN = %r{/[sr]/[^/?#]+/media/[^/?#]+}
  MEDIA_INTERNAL_KEYS = %w[
    photos
    photo
    media
    blob
    blob_id
    signed_id
    filename
    original_filename
    file_name
    content_type
    media_handle
    public_media_handle
    media_path
    public_media_path
    media_url
  ].freeze

  def initialize(recipe, generated_at: Time.current)
    @recipe = recipe
    @generated_at = generated_at
  end

  class << self
    def scrub_media_internals(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested_value), payload|
          key_name = key.to_s
          next if media_internal_key?(key_name)

          scrubbed_value = scrub_media_internals(nested_value)
          next if scrubbed_value.nil?

          payload[key] = scrubbed_value
        end
      when Array
        value.each_with_object([]) do |nested_value, payload|
          scrubbed_value = scrub_media_internals(nested_value)
          payload << scrubbed_value unless scrubbed_value.nil?
        end
      when String
        value unless media_internal_string?(value)
      else
        value
      end
    end

    private
      def media_internal_key?(key)
        key.end_with?("attachment_id") || key.end_with?("attachment_ids") || MEDIA_INTERNAL_KEYS.include?(key)
      end

      def media_internal_string?(value)
        MEDIA_PATH_MARKERS.any? { |marker| value.include?(marker) } || value.match?(PUBLIC_MEDIA_PATH_PATTERN)
      end
  end

  def call
    {
      "schema" => SCHEMA,
      "version" => VERSION,
      "generated_at" => generated_at.iso8601,
      "recipe" => {
        "title" => recipe.title,
        "method" => recipe.method,
        "profile" => self.class.scrub_media_internals(recipe.profile.deep_dup),
        "source_snapshot" => self.class.scrub_media_internals(recipe.source_snapshot.deep_dup),
        "links" => link_payloads
      }
    }
  end

  private
    attr_reader :recipe, :generated_at

    def link_payloads
      recipe.record_links.publicly_visible.map do |link|
        {
          "label" => link.label,
          "url" => link.url,
          "kind" => link.kind,
          "position" => link.position
        }
      end
    end
end
