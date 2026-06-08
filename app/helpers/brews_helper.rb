module BrewsHelper
  def brew_card_timestamp(brew)
    profile_timestamp(brew.occurred_at)
  end

  def brew_card_grams(value)
    profile_grams(value)
  end

  def brew_card_seconds(value)
    return t("brews.show.unknown") if value.blank?

    "#{value}s"
  end

  def brew_card_temperature(value)
    profile_temperature(value)
  end

  def brew_card_boolean(value)
    return t("brews.show.unknown") if value.nil?

    value ? t("brews.show.yes") : t("brews.show.no")
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

  def brew_card_retention_grams(brew)
    return t("brews.show.unknown") if brew.bean_weight_grams.blank? || brew.ground_weight_grams.blank?

    brew_card_grams(brew.bean_weight_grams.to_d - brew.ground_weight_grams.to_d)
  end

  def brew_card_axis_max_grams(value)
    return if value.blank?

    grams = value.to_d
    return if grams <= 0

    ((grams / 5).floor + 1) * 5
  end

  def brew_card_chart_x(seconds, total_seconds)
    return if seconds.blank? || total_seconds.blank? || total_seconds.to_f <= 0

    start_x = 44
    end_x = 500
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

  def brew_card_tools(brew)
    brew.brew_preparation_tools.includes(:preparation_tool).order(:position)
  end

  def brew_card_tool_path(brew_preparation_tool)
    tool = brew_preparation_tool.preparation_tool
    return preparation_tools_path unless tool

    preparation_tool_path(tool)
  end

  def quick_drip_consumed_grams(brew)
    grams = brew_card_grams(brew.bean_weight_grams)
    brew.coffee_amount_estimated_spoons? ? "~#{grams}" : grams
  end

  def quick_drip_estimate_calculation(brew)
    return unless brew.coffee_amount_estimated_spoons?
    return unless brew.coffee_spoons.present? && brew.grams_per_coffee_spoon.present?

    t(
      "brews.show.quick_drip_estimate",
      spoons: profile_number(brew.coffee_spoons, precision: 2),
      grams_per_spoon: profile_grams(brew.grams_per_coffee_spoon),
      grams: quick_drip_consumed_grams(brew)
    )
  end

  def quick_drip_coffee_amount_label(brew)
    return t("brews.show.coffee_spoons", count: profile_number(brew.coffee_spoons, precision: 2)) if brew.coffee_spoons.present?
    return quick_drip_consumed_grams(brew) if brew.bean_weight_grams.present?

    t("brews.show.unknown")
  end

  def brew_taste_label(value, method: "espresso")
    return t("brews.show.unknown") if value.blank? || value == "unknown"

    if method == "quick_drip"
      t("brews.taste.quick_drip.#{value}", default: value.humanize)
    else
      value.humanize
    end
  end

  def brew_card_photo_attachment(brew)
    brew.bean.primary_photo_attachment || brew.primary_photo_attachment
  end

  def brew_card_recipe_targets(brew)
    snapshot = brew.recipe_snapshot
    return {} unless snapshot.is_a?(Hash)

    targets = snapshot["targets"]
    targets.is_a?(Hash) ? targets : {}
  end

  def brew_card_recipe_target_integer(targets, key)
    value = targets[key.to_s]
    return if value.blank?

    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  def brew_card_recipe_target_decimal(targets, key)
    value = targets[key.to_s]
    return if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def brew_related_photo_groups(brew)
    [
      related_photo_group(t("brews.show.related_bean_photos"), brew.bean.display_name, brew.bean),
      *related_equipment_photo_groups(brew),
      *related_preparation_tool_photo_groups(brew)
    ].compact
  end

  private
    def related_photo_group(title, name, record)
      return unless record&.photos&.attached?

      { title:, name:, record: }
    end

    def related_equipment_photo_groups(brew)
      [ brew.grinder, brew.machine, brew.brewer ].compact.uniq.map do |equipment|
        related_photo_group(t("brews.show.related_equipment_photos"), equipment.name, equipment)
      end
    end

    def related_preparation_tool_photo_groups(brew)
      brew_card_tools(brew).filter_map(&:preparation_tool).uniq.map do |tool|
        related_photo_group(t("brews.show.related_tool_photos"), tool.name, tool)
      end
    end

    def brew_card_decimal(value)
      profile_number(value, precision: 2)
    end
end
