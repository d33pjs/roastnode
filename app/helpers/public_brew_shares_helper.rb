module PublicBrewSharesHelper
  def public_media_url_for(share, attachment_id, variant: nil)
    return if attachment_id.blank?

    media_handle = share.public_media_handle_for(attachment_id)
    return if media_handle.blank?

    public_brew_media_path(share.token, media_handle, variant:)
  end

  def public_snapshot_grams(value)
    return public_unknown_label if value.blank?

    "#{public_snapshot_decimal(value)}g"
  end

  def public_snapshot_temperature(value)
    return public_unknown_label if value.blank?

    "#{public_snapshot_decimal(value)}°C"
  end

  def public_snapshot_seconds(value)
    return public_unknown_label if value.blank?

    "#{value}s"
  end

  def public_snapshot_date(value)
    date = Date.iso8601(value.to_s)
    l(date, format: :long)
  rescue ArgumentError, TypeError
    nil
  end

  def public_snapshot_ratio(snapshot)
    dose = public_snapshot_decimal_value(snapshot.dig("brew", "dose_grams"))
    beverage = public_snapshot_decimal_value(snapshot.dig("brew", "beverage_grams"))
    return public_unknown_label if dose.zero? || beverage.zero?

    "1:#{public_snapshot_decimal(beverage / dose, precision: 2)}"
  end

  def public_snapshot_ratio_time(snapshot)
    seconds = snapshot.dig("brew", "total_time_seconds")
    return if seconds.blank?

    t("brews.show.ratio_time", time: public_snapshot_seconds(seconds))
  end

  def public_snapshot_chart_x(seconds, total_seconds)
    return if seconds.blank? || total_seconds.blank? || total_seconds.to_f <= 0

    start_x = 44
    end_x = 500
    (start_x + (seconds.to_f / total_seconds.to_f * (end_x - start_x))).clamp(start_x, end_x).round
  end

  def public_snapshot_axis_max_grams(value)
    return if value.blank?

    grams = value.to_d
    return if grams <= 0

    ((grams / 5).floor + 1) * 5
  end

  def public_lightbox_sources_for(share, snapshot)
    attachment_ids = []
    attachment_ids.concat(Array(snapshot["photos"]).filter_map { |photo| photo["attachment_id"] })
    attachment_ids.concat(Array(snapshot.dig("bean", "photos")).filter_map { |photo| photo["attachment_id"] })
    attachment_ids << snapshot.dig("bean", "photo_attachment_id")
    Array(snapshot["equipment"]).each do |section|
      attachment_ids.concat(Array(section["photos"]).filter_map { |photo| photo["attachment_id"] })
      attachment_ids << section["photo_attachment_id"]
    end
    Array(snapshot["tools"]).each do |section|
      attachment_ids.concat(Array(section["photos"]).filter_map { |photo| photo["attachment_id"] })
      attachment_ids << section["photo_attachment_id"]
    end

    attachment_ids.compact_blank.uniq.filter_map { |attachment_id| public_media_url_for(share, attachment_id) }
  end

  def public_lightbox_index_for(sources, full_url)
    sources.index(full_url).presence || 0
  end

  def public_snapshot_rating_label(rating)
    return public_unknown_label if rating.blank?

    t("brews.show.rating_beans", rating:, maximum: 5)
  end

  def public_snapshot_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def public_product_anchor(prefix, value)
    [ prefix, value.presence || t("public_brew_pages.show.unknown") ].join("-").parameterize
  end

  def public_link_label(link)
    link["label"].presence || t("public_brew_pages.show.#{link["kind"]}", default: t("public_brew_pages.show.info"))
  end

  def public_brew_recipient_byline(logger, recipient)
    logger = logger.is_a?(Hash) ? logger : {}
    recipient = recipient.is_a?(Hash) ? recipient : {}
    target = case recipient["kind"]
    when "self"
      t("brews.recipients.themself")
    when "household_member"
      recipient["display_label"].presence || t("brews.recipients.a_household_member")
    when "guest"
      t("brews.recipients.a_guest")
    else
      t("brews.recipients.someone")
    end

    t(
      "brews.recipients.byline",
      logger: logger["display_label"].presence || t("public_brew_pages.show.unknown"),
      recipient: target
    )
  end

  private
    def public_snapshot_decimal(value, precision: 1)
      number_with_precision(
        public_snapshot_decimal_value(value),
        precision:,
        strip_insignificant_zeros: true,
        separator: ".",
        delimiter: ","
      )
    end

    def public_unknown_label
      t("public_brew_pages.show.unknown")
    end

    def public_snapshot_decimal_value(value)
      return 0.to_d if value.blank?

      value.to_d
    end
end
