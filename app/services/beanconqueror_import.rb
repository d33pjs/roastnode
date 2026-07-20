class BeanconquerorImport
  SOURCE = "beanconqueror"

  def initialize(workspace:, user:, json:)
    @workspace = workspace
    @user = user
    @json = json
    @summary = new_summary
    @warnings = []
    @beans_by_source_id = {}
    @grinders_by_source_id = {}
    @machines_by_source_id = {}
    @tools_by_source_id = {}
    @preparations_by_source_id = {}
  end

  def call
    payload = parse_payload
    return failed_import(payload[:warning]) if payload[:error]

    @payload = payload[:data]
    @data_import = DataImport.create!(
      workspace:,
      user:,
      source: SOURCE,
      status: "pending",
      raw_payload: @payload,
      summary: @summary,
      warnings: @warnings
    )

    ActiveRecord::Base.transaction do
      import_beans
      import_mills
      import_preparations
      import_brews
      data_import.update!(status: "completed", summary:, warnings:)
    end

    data_import
  end

  private
    attr_reader :workspace, :user, :json, :payload, :data_import, :summary, :warnings

    def parse_payload
      { data: JSON.parse(json) }
    rescue JSON::ParserError => error
      { error: true, warning: "Invalid JSON: #{error.message}" }
    end

    def failed_import(warning)
      DataImport.create!(
        workspace:,
        user:,
        source: SOURCE,
        status: "failed",
        summary:,
        warnings: [ warning ],
        raw_payload: {}
      )
    end

    def import_beans
      each_record("BEANS") do |raw|
        source_id = source_id(raw)
        next skip("beans", "Bean without source UUID skipped.") if source_id.blank?

        if (existing = find_existing(Bean, source_id))
          @beans_by_source_id[source_id] = existing
          next skip("beans", "Bean #{source_id} already imported.")
        end

        bean = workspace.beans.create!(bean_attributes(raw, source_id))
        @beans_by_source_id[source_id] = bean
        created("beans")
      rescue ActiveRecord::RecordInvalid => error
        skip("beans", "Bean #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
      end
    end

    def import_mills
      each_record("MILL") do |raw|
        source_id = source_id(raw)
        next skip("equipment", "Mill without source UUID skipped.") if source_id.blank?

        if (existing = find_existing(Equipment, source_id))
          @grinders_by_source_id[source_id] = existing
          next skip("equipment", "Mill #{source_id} already imported.")
        end

        grinder = workspace.equipment.create!(equipment_attributes(raw, source_id, kind: "grinder"))
        @grinders_by_source_id[source_id] = grinder
        created("equipment")
      rescue ActiveRecord::RecordInvalid => error
        skip("equipment", "Mill #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
      end
    end

    def import_preparations
      each_record("PREPARATION") do |raw|
        source_id = source_id(raw)
        next skip("equipment", "Preparation without source UUID skipped.") if source_id.blank?

        @preparations_by_source_id[source_id] = raw

        machine = find_existing(Equipment, source_id)
        if machine
          skip("equipment", "Preparation #{source_id} already imported.")
        else
          machine = workspace.equipment.create!(equipment_attributes(raw, source_id, kind: "machine"))
          created("equipment")
        end
        @machines_by_source_id[source_id] = machine

        import_preparation_tools(raw)
      rescue ActiveRecord::RecordInvalid => error
        skip("equipment", "Preparation #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
      end
    end

    def import_preparation_tools(preparation)
      Array(preparation["tools"]).each do |raw_tool|
        source_id = source_id(raw_tool)
        next skip("preparation_tools", "Preparation tool without source UUID skipped.") if source_id.blank?

        if (existing = find_existing(PreparationTool, source_id))
          @tools_by_source_id[source_id] = existing
          next skip("preparation_tools", "Preparation tool #{source_id} already imported.")
        end

        tool = workspace.preparation_tools.create!(
          name: presence(raw_tool["name"]) || "Imported preparation tool",
          brew_method: "espresso",
          active: true,
          notes: presence(raw_tool["note"]),
          data_import:,
          import_source: SOURCE,
          import_source_id: source_id,
          raw_import_data: raw_tool
        )
        @tools_by_source_id[source_id] = tool
        created("preparation_tools")
      rescue ActiveRecord::RecordInvalid => error
        skip("preparation_tools", "Preparation tool #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
      end
    end

    def import_brews
      each_record("BREWS") do |raw|
        source_id = source_id(raw)
        next skip("brews", "Brew without source UUID skipped.") if source_id.blank?

        if (existing = find_existing(Brew, source_id))
          next skip("brews", "Brew #{source_id} already imported.")
        end

        next skip("brews", "Unsupported brew #{source_id} skipped.") unless supported_brew?(raw)

        bean = @beans_by_source_id[raw["bean"]]
        next skip("brews", "Brew #{source_id} skipped because bean #{raw["bean"]} was not imported.") unless bean

        bean_weight = positive_decimal(raw["bean_weight_in"]) || positive_decimal(raw["grind_weight"])
        next skip("brews", "Brew #{source_id} skipped because bean weight was missing.") unless bean_weight

        brew = workspace.brews.create!(brew_attributes(raw, source_id, bean, bean_weight))
        brew.snapshot_preparation_tools!(preparation_tools_for(raw))
        created("brews")
      rescue ActiveRecord::RecordInvalid => error
        skip("brews", "Brew #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
      end
    end

    def bean_attributes(raw, source_id)
      bag_size = positive_decimal(raw["weight"]) || 250.to_d
      finished = raw["finished"] == true

      {
        name: presence(raw["name"]) || "Imported bean",
        roaster_name: presence(raw["roaster"]),
        origin: origin(raw),
        process: presence(first_bean_information(raw)["processing"]),
        roast_date: date(raw["roastingDate"]),
        roast_level: roast(raw),
        roast_type: roast_type(raw),
        roast_degree: roast_degree(raw),
        blend_type: blend_type(raw),
        tasting_notes: presence(raw["aromatics"]),
        bag_size_grams: bag_size,
        remaining_grams: finished ? 0 : bag_size,
        opened_on: date(raw["openDate"]),
        archived_at: finished ? Time.current : nil,
        purchase_url: Bean.safe_purchase_url(raw["url"]),
        purchased_on: date(raw["buyDate"]),
        purchase_price_cents: cents(raw["cost"]),
        rating: rating(raw["rating"]),
        decaffeinated: truthy?(raw["decaffeinated"]) || truthy?(raw["decaf"]),
        country: presence(first_bean_information(raw)["country"]),
        region: presence(first_bean_information(raw)["region"]),
        farm: presence(first_bean_information(raw)["farm"]),
        farmer: presence(first_bean_information(raw)["farmer"]),
        elevation: presence(first_bean_information(raw)["elevation"]),
        variety: presence(first_bean_information(raw)["variety"]),
        harvested: presence(first_bean_information(raw)["harvested"]) || presence(first_bean_information(raw)["crop_date"]),
        blend_percentage: presence(first_bean_information(raw)["percentage"]),
        notes: presence(raw["note"]),
        data_import:,
        import_source: SOURCE,
        import_source_id: source_id,
        raw_import_data: raw
      }
    end

    def equipment_attributes(raw, source_id, kind:)
      {
        name: presence(raw["name"]) || "Imported #{kind}",
        kind:,
        preinfusion_enabled: kind == "machine",
        notes: presence(raw["note"]),
        data_import:,
        import_source: SOURCE,
        import_source_id: source_id,
        raw_import_data: raw
      }
    end

    def brew_attributes(raw, source_id, bean, bean_weight)
      grind_weight = positive_decimal(raw["grind_weight"])
      {
        user:,
        bean:,
        grinder: @grinders_by_source_id[raw["mill"]],
        machine: @machines_by_source_id[raw["method_of_preparation"]],
        method: "espresso",
        occurred_at: timestamp(raw),
        bean_weight_grams: bean_weight,
        ground_weight_grams: grind_weight,
        dose_grams: grind_weight,
        beverage_grams: positive_decimal(raw["brew_beverage_quantity"]) || positive_decimal(raw["brew_quantity"]),
        grind_setting: presence(raw["grind_size"]),
        brew_temperature_celsius: positive_decimal(raw["brew_temperature"]),
        total_time_seconds: positive_integer(raw["brew_time"]),
        preinfusion_seconds: positive_integer(raw["coffee_blooming_time"]),
        first_drip_seconds: positive_integer(raw["coffee_first_drip_time"]),
        taste_balance: "unknown",
        rating: rating(raw["rating"]),
        notes: presence(raw["note"]),
        data_import:,
        import_source: SOURCE,
        import_source_id: source_id,
        raw_import_data: raw
      }
    end

    def preparation_tools_for(raw)
      Array(raw["method_of_preparation_tools"]).filter_map { |source_id| @tools_by_source_id[source_id] }
    end

    def supported_brew?(raw)
      coffee_type = raw["coffee_type"].to_s.downcase
      return false if coffee_type.present? && !coffee_type.match?(/espresso|ristretto/)

      preparation = @preparations_by_source_id[raw["method_of_preparation"]]
      preparation_type = preparation&.fetch("type", "").to_s.downcase
      preparation_type.blank? || preparation_type.match?(/espresso|portafilter/)
    end

    def each_record(key, &block)
      Array(payload[key]).each(&block)
    end

    def find_existing(model, source_id)
      model.find_by(workspace:, import_source: SOURCE, import_source_id: source_id)
    end

    def source_id(raw)
      presence(raw.dig("config", "uuid"))
    end

    def origin(raw)
      [ first_bean_information(raw)["country"], first_bean_information(raw)["region"] ].filter_map { |value| presence(value) }.join(", ").presence
    end

    def first_bean_information(raw)
      Array(raw["bean_information"]).first || {}
    end

    def roast(raw)
      value = presence(raw["roast_custom"]) || presence(raw["roast"])
      return if value.blank? || value == "UNKNOWN"

      value.to_s.humanize
    end

    def roast_type(raw)
      normalize_option(raw["roast_type"] || raw["roastType"], Bean::ROAST_TYPES)
    end

    def roast_degree(raw)
      value = positive_decimal(raw["roast_degree"] || raw["roastDegree"] || raw["degreeOfRoast"])
      value if value && value <= 5
    end

    def blend_type(raw)
      normalize_option(raw["blend_type"] || raw["blendType"], Bean::BLEND_TYPES)
    end

    def normalize_option(value, allowed)
      normalized = value.to_s.downcase.tr(" -", "_")
      allowed.include?(normalized) ? normalized : "unknown"
    end

    def truthy?(value)
      value == true || value.to_s.downcase.in?(%w[true 1 yes])
    end

    def date(value)
      return if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def timestamp(raw)
      unix_timestamp = raw.dig("config", "unix_timestamp")
      return Time.zone.at(unix_timestamp) if unix_timestamp.present?

      Time.current
    end

    def positive_decimal(value)
      decimal = BigDecimal(value.to_s)
      decimal.positive? ? decimal : nil
    rescue ArgumentError, TypeError
      nil
    end

    def positive_integer(value)
      integer = value.to_i
      integer.positive? ? integer : nil
    end

    def cents(value)
      decimal = positive_decimal(value)
      (decimal * 100).round if decimal
    end

    def rating(value)
      integer = value.to_i
      integer if integer.between?(0, 5) && integer.positive?
    end

    def presence(value)
      value.presence
    end

    def created(key)
      summary[key]["created"] += 1
    end

    def skip(key, warning)
      summary[key]["skipped"] += 1
      warnings << warning
    end

    def new_summary
      Hash.new { |hash, key| hash[key] = { "created" => 0, "skipped" => 0 } }
    end
end
