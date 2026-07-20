require "csv"

class WorkspaceCsvExportBuilder
  BEAN_COLUMNS = %w[
    id name roaster_name status remaining_grams bag_size_grams opened_on finished_at archived_at
    roast_date roast_type grind_state roast_degree blend_type decaffeinated continent country region farm farmer
    elevation variety process harvested blend_percentage country_of_manufacturer manufacturer tasting_notes rating
    purchase_source purchase_url purchased_on purchase_price notes created_at updated_at
  ].freeze

  BREW_COLUMNS = %w[
    id occurred_at method user_display_name user_email_address bean_id bean_name bean_roaster_name
    grinder_id grinder_name machine_id machine_name brewer_id brewer_name preparation_tools bean_weight_grams
    ground_weight_grams dose_grams beverage_grams machine_cups coffee_spoons grams_per_coffee_spoon
    coffee_amount_source brew_ratio grind_setting brew_temperature_celsius
    total_time_seconds preinfusion_seconds low_flow_start_seconds first_drip_seconds channeling flow_control_used taste_balance rating
    served_for_guest guest_name cup_style retention_marker notes created_at updated_at
  ].freeze

  EXTERNAL_COFFEE_COLUMNS = %w[
    id occurred_at user_display_name user_email_address drink_type drink_size place_name place_location
    latitude longitude price currency acidity_balance intensity rating notes public_note created_at updated_at
  ].freeze

  def initialize(workspace)
    @workspace = workspace
  end

  def beans_csv
    CSV.generate(headers: true) do |csv|
      csv << BEAN_COLUMNS

      workspace.beans.order(:id).each do |bean|
        csv << BEAN_COLUMNS.map { |column| bean_value(bean, column) }
      end
    end
  end

  def brews_csv
    CSV.generate(headers: true) do |csv|
      csv << BREW_COLUMNS

      workspace.brews.includes(:user, :bean, :grinder, :machine, :brewer, :brew_preparation_tools).order(:id).each do |brew|
        csv << BREW_COLUMNS.map { |column| brew_value(brew, column) }
      end
    end
  end

  def external_coffees_csv
    CSV.generate(headers: true) do |csv|
      csv << EXTERNAL_COFFEE_COLUMNS

      workspace.external_coffees.includes(:user).order(:id).each do |coffee|
        csv << EXTERNAL_COFFEE_COLUMNS.map { |column| external_coffee_value(coffee, column) }
      end
    end
  end

  private
    attr_reader :workspace

    def bean_value(bean, column)
      case column
      when "status" then bean.bag_status
      when "purchase_price" then money(bean.purchase_price_cents)
      when "remaining_grams", "bag_size_grams", "roast_degree" then decimal(bean.public_send(column))
      when "opened_on", "roast_date", "purchased_on" then date(bean.public_send(column))
      when "finished_at", "archived_at", "created_at", "updated_at" then timestamp(bean.public_send(column))
      else bean.public_send(column)
      end
    end

    def brew_value(brew, column)
      case column
      when "occurred_at", "created_at", "updated_at" then timestamp(brew.public_send(column))
      when "user_display_name" then brew.user.display_label
      when "user_email_address" then brew.user.email_address
      when "bean_name" then brew.bean.name
      when "bean_roaster_name" then brew.bean.roaster_name
      when "grinder_name" then brew.grinder&.name
      when "machine_name" then brew.machine&.name
      when "brewer_name" then brew.brewer&.name
      when "preparation_tools" then brew.brew_preparation_tools.order(:position, :id).pluck(:tool_name).join("; ")
      when "brew_ratio" then brew_ratio(brew)
      when "bean_weight_grams", "ground_weight_grams", "dose_grams", "beverage_grams", "machine_cups",
        "coffee_spoons", "grams_per_coffee_spoon", "brew_temperature_celsius"
        decimal(brew.public_send(column))
      else brew.public_send(column)
      end
    end

    def external_coffee_value(coffee, column)
      case column
      when "occurred_at", "created_at", "updated_at" then timestamp(coffee.public_send(column))
      when "user_display_name" then coffee.user.display_label
      when "user_email_address" then coffee.user.email_address
      when "price" then money(coffee.price_cents)
      when "latitude", "longitude" then decimal(coffee.public_send(column))
      else coffee.public_send(column)
      end
    end

    def brew_ratio(brew)
      return if brew.dose_grams.blank? || brew.beverage_grams.blank? || brew.dose_grams.zero?

      "1:#{format('%.2f', brew.beverage_grams / brew.dose_grams)}"
    end

    def money(cents)
      return if cents.blank?

      format("%.2f", cents / 100.0)
    end

    def decimal(value)
      value&.to_s("F")
    end

    def timestamp(value)
      value&.iso8601
    end

    def date(value)
      value&.iso8601
    end
end
