module PublicBeanSharesHelper
  def public_bean_media_url_for(share, attachment_id, variant: nil)
    return if attachment_id.blank?

    media_handle = share.public_media_handle_for(attachment_id)
    return if media_handle.blank?

    public_bean_media_path(share.token, media_handle, variant:)
  end

  def public_bean_grams(value)
    return public_bean_unknown_label if value.blank?

    "#{public_bean_decimal(value)}g"
  end

  def public_bean_seconds(value)
    return public_bean_unknown_label if value.blank?

    "#{value}s"
  end

  def public_bean_percent(value)
    return public_bean_unknown_label if value.blank?

    "#{value}%"
  end

  def public_bean_rating(value)
    return public_bean_unknown_label if value.blank?

    "#{public_bean_decimal(value)}/5"
  end

  def public_bean_date(value)
    date = Date.iso8601(value.to_s)
    l(date, format: :long)
  rescue ArgumentError, TypeError
    nil
  end

  def public_bean_timeline_position(opened_on, end_at, occurred_at)
    return 0 if opened_on.blank? || end_at.blank? || occurred_at.blank?

    start_time = Time.zone.parse(opened_on.to_s)
    end_time = Time.zone.parse(end_at.to_s)
    event_time = Time.zone.parse(occurred_at.to_s)
    duration = end_time - start_time
    return 0 if duration <= 0

    (((event_time - start_time) / duration) * 100).round.clamp(0, 100)
  rescue ArgumentError, TypeError
    0
  end

  def public_bean_link_label(link)
    link["label"].presence || t("public_bean_pages.show.#{link["kind"].presence || "info"}", default: t("public_bean_pages.show.info"))
  end

  def public_bean_method_label(method)
    case method
    when "quick_drip"
      t("public_bean_pages.show.quick_drip")
    when "espresso"
      t("public_bean_pages.show.espresso")
    else
      method.to_s.humanize.presence || public_bean_unknown_label
    end
  end

  private
    def public_bean_unknown_label
      t("public_bean_pages.show.unknown")
    end

    def public_bean_decimal(value)
      number_with_precision(
        value.to_d,
        precision: 1,
        strip_insignificant_zeros: true,
        separator: ".",
        delimiter: ","
      )
    end
end
