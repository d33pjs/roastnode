class PublicRecipeShareSnapshotBuilder
  TARGET_KEYS = %w[
    bean_weight_grams
    ground_weight_grams
    dose_grams
    beverage_grams
    grind_setting
    brew_temperature_celsius
    preinfusion_seconds
    first_drip_seconds
    total_time_seconds
  ].freeze

  GUIDE_KEYS = %w[note pressure_note].freeze
  SOURCE_BREW_KEYS = %w[occurred_at public_note taste_balance rating].freeze
  BEAN_KEYS = %w[
    name
    display_name
    roaster_name
    origin
    process
    roast_date
    roast_type
    roast_level
    roast_degree
    tasting_notes
    public_note
  ].freeze
  EQUIPMENT_KEYS = %w[name kind model public_note].freeze
  TOOL_KEYS = %w[name brew_method position public_note].freeze
  INGREDIENT_KEYS = %w[amount unit name].freeze
  INGREDIENT_MAX_LENGTHS = {
    "amount" => 32,
    "unit" => 32,
    "name" => 120
  }.freeze
  FINISH_NOTE_MAX_LENGTH = 1_000

  def initialize(recipe:, title:, selected_photo_attachment_ids: [])
    @recipe = recipe
    @title = title
    @profile = recipe.profile || {}
    @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i).uniq
  end

  def call
    {
      "title" => title.presence || profile["title"].presence || recipe.title,
      "workspace" => workspace_payload,
      "user" => user_payload,
      "recipe" => recipe_payload,
      "bean" => bean_payload,
      "equipment" => equipment_payload,
      "tools" => tool_payloads,
      "generated_at" => Time.current.iso8601
    }
  end

  private
    attr_reader :recipe, :title, :profile, :selected_photo_attachment_ids

    def workspace_payload
      { "name" => recipe.workspace.name }
    end

    def user_payload
      { "display_label" => recipe.created_by.display_label }
    end

    def recipe_payload
      {
        "method" => profile["method"].presence || recipe.method,
        "targets" => slice_hash(profile["targets"], TARGET_KEYS),
        "guide" => slice_hash(profile["guide"], GUIDE_KEYS),
        "ingredients" => ingredient_payloads,
        "finish_note" => sanitized_finish_note,
        "source_brew" => source_brew_payload,
        "links" => link_payloads(recipe)
      }.compact
    end

    def ingredient_payloads
      Array(profile["ingredients"]).filter_map do |ingredient|
        next unless ingredient.is_a?(Hash)

        payload = INGREDIENT_KEYS.each_with_object({}) do |key, result|
          value = ingredient[key].to_s.strip.first(INGREDIENT_MAX_LENGTHS.fetch(key))
          result[key] = value if value.present?
        end
        payload if payload["name"].present?
      end
    end

    def sanitized_finish_note
      profile["finish_note"].to_s.strip.first(FINISH_NOTE_MAX_LENGTH).presence
    end

    def source_brew_payload
      source = slice_hash(profile["source_brew"], SOURCE_BREW_KEYS)
      links = profile.dig("source_brew", "links")
      source["links"] = public_link_payloads(links) if links.present?
      source.compact
    end

    def bean_payload
      bean = slice_hash(profile["bean"], BEAN_KEYS)
      links = profile.dig("bean", "links")
      bean["links"] = public_link_payloads(links) if links.present?
      bean.compact
    end

    def equipment_payload
      equipment = profile["equipment"] || {}
      [
        equipment_item_payload(equipment["grinder"], "grinder"),
        equipment_item_payload(equipment["machine"], "machine")
      ].compact
    end

    def equipment_item_payload(source, role)
      return if source.blank?

      payload = slice_hash(source, EQUIPMENT_KEYS)
      payload["role"] = role
      links = source["links"]
      payload["links"] = public_link_payloads(links) if links.present?
      payload.compact
    end

    def tool_payloads
      Array(profile["tools"]).map do |source|
        payload = slice_hash(source, TOOL_KEYS)
        links = source["links"]
        payload["links"] = public_link_payloads(links) if links.present?
        payload.compact
      end
    end

    def link_payloads(record)
      record.record_links.publicly_visible.map do |link|
        {
          "label" => link.label,
          "url" => link.url,
          "kind" => link.kind,
          "position" => link.position
        }
      end
    end

    def public_link_payloads(links)
      Array(links).filter_map do |link|
        next unless link["url"].present?
        next if link["visibility"].present? && link["visibility"] != "public"

        {
          "label" => link["label"],
          "url" => link["url"],
          "kind" => link["kind"],
          "position" => link["position"]
        }.compact
      end
    end

    def slice_hash(source, allowed_keys)
      source = source || {}
      allowed_keys.each_with_object({}) do |key, payload|
        value = source[key]
        payload[key] = value if value.present?
      end
    end
end
