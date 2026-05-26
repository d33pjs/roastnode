module BrewsHelper
  def brew_card_timestamp(brew)
    l(brew.occurred_at, format: :european_seconds)
  end

  def brew_card_grams(value)
    return t("brews.show.unknown") if value.blank?

    "#{number_with_precision(value, precision: 1, strip_insignificant_zeros: true)} g"
  end

  def brew_card_seconds(value)
    return t("brews.show.unknown") if value.blank?

    "#{value}s"
  end

  def brew_card_temperature(value)
    return t("brews.show.unknown") if value.blank?

    "#{number_with_precision(value, precision: 1, strip_insignificant_zeros: true)}°C"
  end

  def brew_card_ratio(brew)
    ratio = brew_card_ratio_value(brew)
    return ratio if ratio == t("brews.show.unknown") || brew.total_time_seconds.blank?

    t("brews.show.ratio_with_time", ratio: ratio.delete_prefix("1:"), time: brew_card_seconds(brew.total_time_seconds))
  end

  def brew_card_ratio_value(brew)
    return t("brews.show.unknown") if brew.dose_grams.blank? || brew.beverage_grams.blank?
    return t("brews.show.unknown") if brew.dose_grams.to_d.zero?

    ratio = brew.beverage_grams.to_d / brew.dose_grams.to_d
    "1:#{brew_card_decimal(ratio)}"
  end

  def brew_card_ratio_time(brew)
    return if brew.total_time_seconds.blank?

    t("brews.show.ratio_time", time: brew_card_seconds(brew.total_time_seconds))
  end

  def brew_card_axis_max_grams(value)
    return if value.blank?

    grams = value.to_d
    return if grams <= 0

    ((grams / 5).floor + 1) * 5
  end

  def brew_card_chart_x(seconds, total_seconds)
    return if seconds.blank? || total_seconds.blank? || total_seconds.to_f <= 0

    start_x = 62
    end_x = 626
    x_position = start_x + (seconds.to_f / total_seconds.to_f * (end_x - start_x))

    x_position.clamp(start_x, end_x).round
  end

  def brew_card_rating_label(rating)
    return t("brews.show.unknown") if rating.blank?

    t("brews.show.rating_beans", rating:, maximum: 5)
  end

  def brew_card_bean_descriptor(bean)
    [ bean.origin, bean.process, bean.roast_level ].compact_blank.join(" · ")
  end

  def brew_card_tool_names(brew)
    brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  private
    def brew_card_decimal(value)
      number_with_precision(value, precision: 2, strip_insignificant_zeros: true).tr(".", ",")
    end
end
