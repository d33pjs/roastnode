class RecipeExporter
  SCHEMA = "roastnode.recipe"
  VERSION = 1

  def initialize(recipe, generated_at: Time.current)
    @recipe = recipe
    @generated_at = generated_at
  end

  def call
    {
      "schema" => SCHEMA,
      "version" => VERSION,
      "generated_at" => generated_at.iso8601,
      "recipe" => {
        "title" => recipe.title,
        "method" => recipe.method,
        "profile" => recipe.profile.deep_dup,
        "source_snapshot" => recipe.source_snapshot.deep_dup,
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
