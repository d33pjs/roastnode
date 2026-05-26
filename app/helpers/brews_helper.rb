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
end
