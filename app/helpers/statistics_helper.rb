module StatisticsHelper
  def statistics_grams(value)
    "#{profile_number(value || 0, precision: 1)}g"
  end

  def statistics_money(cents)
    return t("statistics.index.unknown") if cents.blank?

    amount = cents.to_d / 100
    "#{profile_number(amount, precision: 2, strip_insignificant_zeros: false)} #{current_workspace.default_currency}"
  end

  def statistics_percent(value)
    "#{value || 0}%"
  end

  def statistics_bar_width(value, maximum)
    return 0 if maximum.blank? || maximum.to_d.zero?

    ((value.to_d / maximum) * 100).round
  end
end
