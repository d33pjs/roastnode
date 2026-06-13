module BeansHelper
  def bean_origin_label(bean)
    bean.origin_display_value.presence || t("beans.show.unknown_origin")
  end

  def bean_purchase_url_label(url)
    uri = URI.parse(url.to_s)
    host = uri.host.presence || url.to_s
    path = uri.path.to_s
    label = path.present? && path != "/" ? "#{host}#{path}" : host
    label.length > 24 ? "#{label.first(23)}..." : label
  rescue URI::InvalidURIError
    url.to_s.length > 24 ? "#{url.to_s.first(23)}..." : url.to_s
  end
end
