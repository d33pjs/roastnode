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

  def public_snapshot_ratio(snapshot)
    dose = public_snapshot_decimal_value(snapshot.dig("brew", "dose_grams"))
    beverage = public_snapshot_decimal_value(snapshot.dig("brew", "beverage_grams"))
    return public_unknown_label if dose.zero? || beverage.zero?

    "1:#{public_snapshot_decimal(beverage / dose, precision: 2)}"
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
