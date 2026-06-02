class RecipeImporter
  class ImportError < StandardError; end

  def initialize(workspace:, user:, json:)
    @workspace = workspace
    @user = user
    @json = json
  end

  def call
    payload = parse_payload
    validate_payload!(payload)
    recipe_payload = payload.fetch("recipe")

    Recipe.transaction do
      recipe = workspace.recipes.create!(
        created_by: user,
        title: recipe_payload.fetch("title"),
        method: recipe_payload.fetch("method"),
        profile: recipe_payload.fetch("profile"),
        source_snapshot: recipe_payload.fetch("source_snapshot"),
        source_brew: nil
      )
      create_links!(recipe, recipe_payload.fetch("links", []))
      recipe
    end
  end

  private
    attr_reader :workspace, :user, :json

    def parse_payload
      JSON.parse(json)
    rescue JSON::ParserError => error
      raise ImportError, "Invalid JSON: #{error.message}"
    end

    def validate_payload!(payload)
      raise ImportError, "Invalid recipe export." unless payload.is_a?(Hash)
      raise ImportError, "Unsupported recipe schema." unless payload["schema"] == RecipeExporter::SCHEMA
      raise ImportError, "Unsupported recipe version." unless payload["version"] == RecipeExporter::VERSION

      recipe_payload = payload["recipe"]
      raise ImportError, "Missing recipe payload." unless recipe_payload.is_a?(Hash)
      raise ImportError, "Missing recipe title." if recipe_payload["title"].blank?
      raise ImportError, "Unsupported recipe method." unless Recipe.defined_enums.fetch("method").key?(recipe_payload["method"])
      raise ImportError, "Missing recipe profile." unless recipe_payload["profile"].is_a?(Hash) && recipe_payload["profile"].present?
      raise ImportError, "Missing source snapshot." unless recipe_payload["source_snapshot"].is_a?(Hash) && recipe_payload["source_snapshot"].present?

      validate_links!(recipe_payload.fetch("links", []))
    end

    def validate_links!(links)
      raise ImportError, "Recipe links must be an array." unless links.is_a?(Array)

      links.each do |link|
        raise ImportError, "Recipe links must be objects." unless link.is_a?(Hash)
        raise ImportError, "Recipe link label is missing." if link["label"].blank?
        validate_link_url!(link["url"])
      end
    end

    def validate_link_url!(url)
      uri = URI.parse(url.to_s)
      return if uri.is_a?(URI::HTTP) && uri.host.present?

      raise ImportError, "Recipe link URL must be an HTTP or HTTPS URL."
    rescue URI::InvalidURIError
      raise ImportError, "Recipe link URL must be an HTTP or HTTPS URL."
    end

    def create_links!(recipe, links)
      links.each_with_index do |link, index|
        recipe.record_links.create!(
          workspace: recipe.workspace,
          label: link.fetch("label"),
          url: link.fetch("url"),
          kind: link["kind"].presence_in(RecordLink::KINDS) || "info",
          visibility: "public",
          position: link["position"].presence || ((index + 1) * 10)
        )
      end
    end
end
