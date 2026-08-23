module BeansHelper
  def bean_origin_label(bean)
    bean.origin_display_value.presence || t("beans.show.unknown_origin")
  end

  def bean_purchase_url_label(url)
    url = url.to_s.strip
    uri = URI.parse(url)
    host = uri.host.presence || url.to_s
    path = uri.path.to_s
    label = path.present? && path != "/" ? "#{host}#{path}" : host
    label.length > 24 ? "#{label.first(23)}..." : label
  rescue URI::InvalidURIError
    url.to_s.length > 24 ? "#{url.to_s.first(23)}..." : url.to_s
  end

  def bean_purchase_url_href(url)
    Bean.safe_purchase_url(url)
  end

  def bean_private_system_links(bean)
    [
      bean_private_system_link(
        bean.purchase_url,
        label: t("beans.show.system_links.purchase"),
        kind: "buy",
        testid: "bean-system-purchase-url"
      ),
      bean_private_system_link(
        bean.coffee_origin_url,
        label: t("beans.show.system_links.origin"),
        kind: "info",
        testid: "bean-system-origin-url"
      )
    ].compact
  end

  private
    def bean_private_system_link(url, label:, kind:, testid:)
      safe_url = Bean.safe_http_url(url)
      return if safe_url.blank?

      {
        label:,
        url: safe_url,
        kind:,
        visibility: "private",
        testid:
      }
    end
end
