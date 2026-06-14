module ApplicationHelper
  MATERIAL_SYMBOL_PATHS = {
    "arrow_back" => "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z",
    "archive" => "M20.54 5.23 19.15 3.55C18.77 3.09 18.21 2.82 17.61 2.82H6.39c-.6 0-1.16.27-1.54.73L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27ZM6.39 4.82h11.22l.81.97H5.58l.81-.97ZM19 19H5V8h14v11Zm-8-2h2v-5h3l-4-4-4 4h3v5Z",
    "bookmark_add" => "M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2Zm-1 7h-3v3h-2v-3H8V8h3V5h2v3h3v2Z",
    "check_circle" => "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2Zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9Z",
    "content_copy" => "M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1Zm3 4H8c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2Zm0 18H8V7h11v16Z",
    "edit" => "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25Zm17.71-10.04c.39-.39.39-1.02 0-1.41l-2.51-2.51a.996.996 0 0 0-1.41 0l-1.96 1.96 3.75 3.75 2.13-1.79Z",
    "file_download" => "M5 20h14v-2H5v2ZM19 9h-4V3H9v6H5l7 7 7-7Z",
    "inventory_2" => "M20 2H4c-1.1 0-2 .9-2 2v3c0 .74.4 1.38 1 1.72V20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8.72c.6-.34 1-.98 1-1.72V4c0-1.1-.9-2-2-2ZM4 4h16v3H4V4Zm15 16H5V9h14v11Zm-9-8h4v2h-4v-2Z",
    "ios_share" => "M16 5l-1.42 1.42-1.59-1.59V16h-2V4.83L9.4 6.42 8 5l4-4 4 4ZM20 10v11c0 1.1-.9 2-2 2H6c-1.1 0-2-.9-2-2V10c0-1.1.9-2 2-2h3v2H6v11h12V10h-3V8h3c1.1 0 2 .9 2 2Z",
    "local_cafe" => "M2 21h18v-2H2v2ZM20 8h-2V5H4v8c0 2.21 1.79 4 4 4h4c2.21 0 4-1.79 4-4h2c1.66 0 3-1.34 3-3s-1.34-3-3-3Zm-6 5c0 1.1-.9 2-2 2H8c-1.1 0-2-.9-2-2V7h8v6Zm4-2h-2V9h2c.55 0 1 .45 1 1s-.45 1-1 1Z",
    "more_vert" => "M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2Zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2Zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2Z",
    "public" => "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2Zm6.93 6h-2.95c-.32-1.25-.82-2.45-1.48-3.53A8.04 8.04 0 0 1 18.93 8ZM12 4.04c.83 1.2 1.48 2.53 1.82 3.96h-3.64c.34-1.43.99-2.76 1.82-3.96ZM4.26 14C4.09 13.36 4 12.69 4 12s.09-1.36.26-2h3.33A16.2 16.2 0 0 0 7.5 12c0 .68.03 1.35.09 2H4.26Zm.81 2h2.95c.32 1.25.82 2.45 1.48 3.53A8.04 8.04 0 0 1 5.07 16Zm2.95-8H5.07A8.04 8.04 0 0 1 9.5 4.47C8.84 5.55 8.34 6.75 8.02 8ZM12 19.96c-.83-1.2-1.48-2.53-1.82-3.96h3.64c-.34 1.43-.99 2.76-1.82 3.96ZM14.25 14h-4.5c-.07-.65-.1-1.32-.1-2s.03-1.35.1-2h4.5c.07.65.1 1.32.1 2s-.03 1.35-.1 2Zm.25 5.53c.66-1.08 1.16-2.28 1.48-3.53h2.95a8.04 8.04 0 0 1-4.43 3.53ZM16.41 14c.06-.65.09-1.32.09-2s-.03-1.35-.09-2h3.33c.17.64.26 1.31.26 2s-.09 1.36-.26 2h-3.33Z",
    "refresh" => "M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h8V3l-3.35 3.35Z",
    "restart_alt" => "M12 5V2L7 7l5 5V9c2.76 0 5 2.24 5 5 0 1.01-.3 1.95-.82 2.74l1.46 1.46A6.96 6.96 0 0 0 19 14c0-3.86-3.14-7-7-7Zm-5 5a6.96 6.96 0 0 0-1.64 4.2c0 3.86 3.14 7 7 7v3l5-5-5-5v3c-2.76 0-5-2.24-5-5 0-1.01.3-1.95.82-2.74L7 10Z",
    "scale" => "M12 3c-.55 0-1 .45-1 1v1H5v2h1.1L3 14.2V15c0 1.66 1.34 3 3 3s3-1.34 3-3v-.8L5.9 7H11v12H8v2h8v-2h-3V7h5.1L15 14.2V15c0 1.66 1.34 3 3 3s3-1.34 3-3v-.8L17.9 7H19V5h-6V4c0-.55-.45-1-1-1ZM5.4 14 6 12.6 6.6 14H5.4Zm12 0 .6-1.4.6 1.4h-1.2Z",
    "shopping_bag" => "M18 6h-2c0-2.21-1.79-4-4-4S8 3.79 8 6H6c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2Zm-6-2c1.1 0 2 .9 2 2h-4c0-1.1.9-2 2-2Zm6 16H6V8h2v2h2V8h4v2h2V8h2v12Z"
  }.freeze

  def material_symbol(name, classes: "material-symbol h-5 w-5")
    symbol_name = name.to_s
    path = MATERIAL_SYMBOL_PATHS.fetch(symbol_name, MATERIAL_SYMBOL_PATHS.fetch("more_vert"))

    tag.svg(
      tag.path(d: path),
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "currentColor",
      class: classes,
      data: { symbol: symbol_name },
      aria: { hidden: true },
      focusable: "false"
    )
  end

  def back_link_path(fallback_path)
    fallback_path = fallback_path.to_s
    referer = request.referer.to_s
    return fallback_path if referer.blank?

    uri = URI.parse(referer)
    return fallback_path unless same_app_back_link_uri?(uri)

    path = uri.relative? ? uri.to_s : uri.request_uri
    return fallback_path if path.blank? || path == request.fullpath
    return fallback_path if workflow_back_link_referrer?(path)

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

    def workflow_back_link_referrer?(path)
      path.match?(%r{\A/(?:brews/\d+/public_brew_share|beans/\d+/public_bean_share|recipes/\d+/public_recipe_share)(?:/(?:new|edit))?(?:\?.*)?\z})
    end
end
