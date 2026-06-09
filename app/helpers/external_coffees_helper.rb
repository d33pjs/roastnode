module ExternalCoffeesHelper
  EXTERNAL_COFFEE_CURRENCY_SYMBOLS = {
    "AUD" => "A$",
    "CAD" => "C$",
    "CHF" => "CHF",
    "CNY" => "¥",
    "DKK" => "kr",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "NOK" => "kr",
    "NZD" => "NZ$",
    "SEK" => "kr",
    "USD" => "$"
  }.freeze

  EXTERNAL_COFFEE_PREFIX_CURRENCIES = %w[AUD CAD CNY GBP JPY NZD USD].freeze

  def external_coffee_price(coffee)
    return t("external_coffees.show.unknown") if coffee.price.blank?

    external_coffee_money(coffee.price, coffee.currency)
  end

  def external_coffee_card_timestamp(coffee)
    value = coffee.occurred_at
    return if value.blank?

    value = value.in_time_zone if value.respond_to?(:in_time_zone)

    case Current.user&.time_format
    when "us_12h_seconds"
      value.strftime("%m/%d/%Y %I:%M %p")
    else
      value.strftime("%d.%m.%Y %H:%M")
    end
  end

  def external_coffee_acidity_label(value)
    t("external_coffees.taste.acidity.#{value}")
  end

  def external_coffee_intensity_label(value)
    t("external_coffees.taste.intensity.#{value}")
  end

  def external_coffee_rating_marks(coffee)
    return t("external_coffees.show.no_rating") if coffee.rating.blank?

    filled = "●" * coffee.rating
    empty = "○" * (5 - coffee.rating)
    "#{filled}#{empty}"
  end

  private
    def external_coffee_money(value, currency)
      formatted_value = profile_number(value, precision: 2, strip_insignificant_zeros: false)
      currency = currency.to_s.upcase
      symbol = EXTERNAL_COFFEE_CURRENCY_SYMBOLS[currency]
      return "#{formatted_value} #{currency}" if symbol.blank?

      if EXTERNAL_COFFEE_PREFIX_CURRENCIES.include?(currency)
        "#{symbol}#{formatted_value}"
      else
        "#{formatted_value} #{symbol}"
      end
    end
end
