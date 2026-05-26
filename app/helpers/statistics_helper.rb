module StatisticsHelper
  def statistics_grams(value)
    "#{number_with_precision(value || 0, precision: 1, strip_insignificant_zeros: true)} g"
  end

  def statistics_money(cents)
    return t("statistics.index.unknown") if cents.blank?

    amount = cents.to_d / 100
    "#{number_with_precision(amount, precision: 2)} #{current_workspace.default_currency}"
  end

  def statistics_percent(value)
    "#{value || 0}%"
  end

  def statistics_bar_width(value, maximum)
    return 0 if maximum.blank? || maximum.to_d.zero?

    ((value.to_d / maximum) * 100).round
  end
end
