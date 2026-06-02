class RecipeSnapshotBuilder
  def initialize(brew:, title:, guide_note: nil, pressure_note: nil)
    @brew = brew
    @title = title
    @guide_note = guide_note
    @pressure_note = pressure_note
  end

  def call
    {
      "title" => title.presence || default_title,
      "method" => brew.method,
      "targets" => target_payload,
      "guide" => guide_payload,
      "source_brew" => source_brew_payload,
      "bean" => bean_payload,
      "equipment" => equipment_payload,
      "tools" => tool_payloads,
      "generated_at" => Time.current.iso8601
    }
  end

  private
    attr_reader :brew, :title, :guide_note, :pressure_note

    def default_title
      "Espresso with #{brew.bean.display_name}"
    end

    def target_payload
      {
        "bean_weight_grams" => decimal_string(brew.bean_weight_grams),
        "ground_weight_grams" => decimal_string(brew.ground_weight_grams),
        "dose_grams" => decimal_string(brew.dose_grams),
        "beverage_grams" => decimal_string(brew.beverage_grams),
        "grind_setting" => brew.grind_setting,
        "brew_temperature_celsius" => decimal_string(brew.brew_temperature_celsius),
        "preinfusion_seconds" => brew.preinfusion_seconds,
        "first_drip_seconds" => brew.first_drip_seconds,
        "total_time_seconds" => brew.total_time_seconds
      }.compact
    end

    def guide_payload
      {
        "note" => guide_note,
        "pressure_note" => pressure_note
      }.compact
    end

    def source_brew_payload
      {
        "id" => brew.id,
        "occurred_at" => brew.occurred_at&.iso8601,
        "public_note" => brew.public_note,
        "taste_balance" => brew.taste_balance,
        "rating" => brew.rating,
        "links" => link_payloads(brew)
      }.compact
    end

    def bean_payload
      bean = brew.bean
      {
        "name" => bean.name,
        "display_name" => bean.display_name,
        "roaster_name" => bean.roaster_name,
        "origin" => bean.origin,
        "process" => bean.process,
        "roast_date" => bean.roast_date&.iso8601,
        "roast_type" => bean.roast_type,
        "roast_level" => bean.roast_level,
        "roast_degree" => decimal_string(bean.roast_degree),
        "tasting_notes" => bean.tasting_notes,
        "public_note" => bean.public_note,
        "links" => link_payloads(bean)
      }.compact
    end

    def equipment_payload
      {
        "grinder" => equipment_item_payload(brew.grinder),
        "machine" => equipment_item_payload(brew.machine)
      }.compact
    end

    def equipment_item_payload(equipment)
      return unless equipment

      {
        "name" => equipment.name,
        "kind" => equipment.kind,
        "model" => equipment.model,
        "public_note" => equipment.public_note,
        "links" => link_payloads(equipment)
      }.compact
    end

    def tool_payloads
      brew.brew_preparation_tools.includes(:preparation_tool).order(:position).map do |snapshot|
        tool = snapshot.preparation_tool
        {
          "name" => snapshot.tool_name,
          "brew_method" => snapshot.brew_method,
          "position" => snapshot.position,
          "public_note" => tool&.public_note,
          "links" => tool ? link_payloads(tool) : []
        }.compact
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

    def decimal_string(value)
      value&.to_s
    end
end
