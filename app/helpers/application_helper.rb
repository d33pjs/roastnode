module ApplicationHelper
  def back_link_path(fallback_path)
    fallback_path = fallback_path.to_s
    referer = request.referer.to_s
    return fallback_path if referer.blank?

    uri = URI.parse(referer)
    return fallback_path unless same_app_back_link_uri?(uri)

    path = uri.relative? ? uri.to_s : uri.request_uri
    return fallback_path if path.blank? || path == request.fullpath

    path
  rescue URI::InvalidURIError
    fallback_path
  end

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

    "#{profile_number(value, precision: 1)}g"
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

  private
    def same_app_back_link_uri?(uri)
      if uri.relative?
        uri.host.blank? && uri.path.to_s.start_with?("/") && !uri.to_s.start_with?("//")
      else
        origin = URI.parse(request.base_url)
        uri.scheme.in?(%w[http https]) &&
          uri.scheme == origin.scheme &&
          uri.host == origin.host &&
          uri.port == origin.port
      end
    end
end
