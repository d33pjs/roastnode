class DemoDataSeeder
  EMAIL = "demo@roastnode.local"
  PASSWORD = "roastnode-demo"
  WORKSPACE_NAME = "Roastnode Demo Household"

  def call
    status = already_seeded? ? "already_present" : "created"

    ActiveRecord::Base.transaction do
      ensure_user!
      ensure_workspace!
      ensure_membership!
      ensure_active_workspace!
      ensure_beans!
      ensure_equipment!
      ensure_preparation_tools!
      ensure_brews!
      ensure_equipment_event!
    end

    {
      status:,
      email: EMAIL,
      password: PASSWORD,
      workspace: WORKSPACE_NAME
    }
  end

  private
    attr_reader :user, :workspace, :beans, :equipment, :preparation_tools

    def already_seeded?
      Workspace.find_by(name: WORKSPACE_NAME)&.brews&.exists? || false
    end

    def ensure_user!
      @user = User.find_or_initialize_by(email_address: EMAIL)
      user.display_name ||= "Demo Barista"
      user.password = PASSWORD if user.new_record?
      user.default_landing_screen ||= "dashboard"
      user.default_brew_focus_field ||= "bean_weight_grams"
      user.save!
    end

    def ensure_workspace!
      @workspace = Workspace.find_or_create_by!(name: WORKSPACE_NAME) do |record|
        record.kind = "household"
        record.default_currency = "EUR"
      end
    end

    def ensure_membership!
      Membership.find_or_create_by!(workspace:, user:) do |membership|
        membership.role = "owner"
      end
    end

    def ensure_active_workspace!
      user.update!(active_workspace: workspace)
    end

    def ensure_beans!
      @beans = {
        house_blend: find_or_create_bean!(
          name: "Demo House Blend",
          roaster_name: "Roastnode Samples",
          origin: "Colombia",
          country: "Colombia",
          region: "Huila",
          farm: "La Esperanza",
          farmer: "Ana Gomez",
          process: "washed",
          variety: "Caturra",
          harvested: "2025",
          roast_date: Date.new(2026, 5, 10),
          roast_type: "espresso",
          roast_degree: 3.0,
          blend_type: "single_origin",
          tasting_notes: "Chocolate, cherry, caramel",
          bag_size_grams: 250,
          remaining_grams: 250,
          opened_on: Date.new(2026, 5, 20),
          purchase_source: "Local demo roaster",
          purchase_price_cents: 1290,
          rating: 4,
          notes: "Seeded demo espresso bean."
        ),
        fruit_lot: find_or_create_bean!(
          name: "Demo Fruit Lot",
          roaster_name: "Roastnode Samples",
          origin: "Ethiopia",
          country: "Ethiopia",
          region: "Yirgacheffe",
          process: "natural",
          variety: "Heirloom",
          harvested: "2025",
          roast_date: Date.new(2026, 5, 12),
          roast_type: "omni",
          roast_degree: 2.5,
          blend_type: "single_origin",
          tasting_notes: "Blueberry, florals, black tea",
          bag_size_grams: 250,
          remaining_grams: 250,
          opened_on: Date.new(2026, 5, 22),
          purchase_source: "Local demo roaster",
          purchase_price_cents: 1490,
          rating: 5,
          notes: "Seeded demo bright bean."
        ),
        filter_ground: find_or_create_bean!(
          name: "Demo Filter Ground",
          roaster_name: "Roastnode Samples",
          origin: "Guatemala",
          country: "Guatemala",
          region: "Antigua",
          process: "washed",
          variety: "Bourbon",
          harvested: "2025",
          roast_date: Date.new(2026, 5, 14),
          roast_type: "filter",
          grind_state: "pre_ground",
          roast_degree: 2.0,
          blend_type: "single_origin",
          tasting_notes: "Cocoa, orange, almond",
          bag_size_grams: 500,
          remaining_grams: 500,
          opened_on: Date.new(2026, 5, 24),
          purchase_source: "Local demo roaster",
          purchase_price_cents: 1690,
          rating: 4,
          notes: "Seeded pre-ground filter bean for Quick Drip demos."
        )
      }
    end

    def ensure_equipment!
      @equipment = {
        grinder: find_or_create_equipment!("Demo Grinder", "grinder", "Single dose"),
        machine: find_or_create_equipment!("Demo Espresso Machine", "machine", "Dual boiler"),
        brewer: find_or_create_equipment!("Demo Quick Drip Brewer", "brewer", "Thermos drip")
      }
    end

    def ensure_preparation_tools!
      @preparation_tools = {
        basket: find_or_create_preparation_tool!("Demo Double Basket"),
        tamper: find_or_create_preparation_tool!("Demo Tamper"),
        wdt: find_or_create_preparation_tool!("Demo WDT"),
        puck_screen: find_or_create_preparation_tool!("Demo Puck Screen"),
        paper_filter: find_or_create_preparation_tool!("Demo Paper Filter", brew_method: "quick_drip")
      }
    end

    def ensure_brews!
      espresso_tools = [
        preparation_tools.fetch(:basket),
        preparation_tools.fetch(:tamper),
        preparation_tools.fetch(:wdt),
        preparation_tools.fetch(:puck_screen)
      ]

      create_brew_once!(
        occurred_at: Time.zone.local(2026, 5, 26, 8, 15, 0),
        bean: beans.fetch(:house_blend),
        beverage_grams: 42,
        grind_setting: "12",
        brew_temperature_celsius: 93,
        total_time_seconds: 31,
        preinfusion_seconds: 6,
        first_drip_seconds: 8,
        taste_balance: "neutral",
        rating: 4,
        notes: "Balanced seeded morning shot.",
        tools: espresso_tools
      )

      create_brew_once!(
        occurred_at: Time.zone.local(2026, 5, 26, 14, 30, 0),
        bean: beans.fetch(:fruit_lot),
        beverage_grams: 45,
        grind_setting: "11.5",
        brew_temperature_celsius: 92,
        total_time_seconds: 33,
        preinfusion_seconds: 7,
        first_drip_seconds: 9,
        taste_balance: "sour",
        rating: 5,
        notes: "Bright seeded afternoon shot.",
        tools: espresso_tools.first(3)
      )

      create_quick_drip_once!(
        occurred_at: Time.zone.local(2026, 5, 27, 9, 0, 0),
        bean: beans.fetch(:filter_ground),
        machine_cups: 6,
        coffee_spoons: 6,
        beverage_grams: 900,
        total_time_seconds: 360,
        taste_balance: "neutral",
        rating: 4,
        notes: "Easy seeded Quick Drip batch.",
        tools: [ preparation_tools.fetch(:paper_filter) ]
      )
    end

    def ensure_equipment_event!
      event = workspace.equipment_events.find_or_initialize_by(
        user:,
        occurred_at: Time.zone.local(2026, 5, 25, 19, 0, 0),
        notes: "Seeded grinder and machine cleaning."
      )
      event.event_types = %w[grinder_cleaning machine_backflush]
      event.equipment = [ equipment.fetch(:grinder), equipment.fetch(:machine) ]
      event.save!
    end

    def find_or_create_bean!(attributes)
      workspace.beans.find_or_create_by!(name: attributes.fetch(:name), roaster_name: attributes.fetch(:roaster_name)) do |bean|
        bean.assign_attributes(attributes)
      end
    end

    def find_or_create_equipment!(name, kind, model)
      workspace.equipment.find_or_create_by!(name:) do |item|
        item.kind = kind
        item.model = model
      end
    end

    def find_or_create_preparation_tool!(name, brew_method: "espresso")
      workspace.preparation_tools.find_or_create_by!(name:) do |tool|
        tool.brew_method = brew_method
        tool.active = true
      end
    end

    def create_brew_once!(attributes)
      brew = workspace.brews.find_or_initialize_by(
        user:,
        bean: attributes.fetch(:bean),
        occurred_at: attributes.fetch(:occurred_at)
      )
      return brew if brew.persisted?

      tools = attributes.delete(:tools)
      brew.assign_attributes(
        grinder: equipment.fetch(:grinder),
        machine: equipment.fetch(:machine),
        bean_weight_grams: 18,
        ground_weight_grams: 17.8,
        dose_grams: 18,
        channeling: false,
        **attributes.except(:bean)
      )
      brew.save!
      brew.snapshot_preparation_tools!(tools)
      brew
    end

    def create_quick_drip_once!(attributes)
      brew = workspace.brews.find_or_initialize_by(
        user:,
        bean: attributes.fetch(:bean),
        occurred_at: attributes.fetch(:occurred_at)
      )
      return brew if brew.persisted?

      tools = attributes.delete(:tools)
      brew.assign_attributes(
        method: "quick_drip",
        brewer: equipment.fetch(:brewer),
        **attributes.except(:bean)
      )
      brew.save!
      brew.snapshot_preparation_tools!(tools)
      brew
    end
end
