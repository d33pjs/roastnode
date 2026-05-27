module ApplicationHelper
  def profile_number(value, precision:, strip_insignificant_zeros: true)
    number_with_precision(
      value,
      precision:,
      strip_insignificant_zeros:,
      separator: profile_decimal_separator,
      delimiter: profile_thousands_delimiter
    )
  end

  def profile_grams(value)
    return t("brews.show.unknown") if value.blank?

    "#{profile_number(value, precision: 1)} g"
  end

  def profile_temperature(value)
    return t("brews.show.unknown") if value.blank?

    "#{profile_number(value, precision: 1)}°C"
  end

  def profile_money(value, currency = current_workspace.default_currency)
    return t("brews.show.unknown") if value.blank?

    "#{profile_number(value, precision: 2, strip_insignificant_zeros: false)} #{currency}"
  end

  def profile_timestamp(value)
    return if value.blank?

    value = value.in_time_zone if value.respond_to?(:in_time_zone)

    case Current.user&.time_format
    when "us_12h_seconds"
      value.strftime("%m/%d/%Y %I:%M:%S %p")
    else
      value.strftime("%d.%m.%Y %H:%M:%S")
    end
  end

  def profile_decimal_separator
    Current.user&.number_format == "dot_decimal" ? "." : ","
  end

  def profile_thousands_delimiter
    Current.user&.number_format == "dot_decimal" ? "," : "."
  end
end
