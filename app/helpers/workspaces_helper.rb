module WorkspacesHelper
  def dashboard_duration_text(since_at, now: Time.current)
    return t("workspaces.show.timer.no_coffee") if since_at.blank?

    seconds = [ (now - since_at).to_i, 0 ].max
    dashboard_format_duration(seconds)
  end

  def dashboard_money(cents)
    amount = cents.to_d / 100
    "#{profile_number(amount, precision: 2, strip_insignificant_zeros: false)} #{current_workspace.default_currency}"
  end

  def dashboard_sparkline_points(values, width: 120, height: 32, padding: 3)
    values = Array(values).map(&:to_d)
    return "" if values.empty?

    minimum = values.min
    maximum = values.max
    range = maximum - minimum
    x_step = values.one? ? 0 : width.to_d / (values.size - 1)

    values.each_with_index.map do |value, index|
      x = (x_step * index).round(2)
      y = if range.zero?
        height.to_d / 2
      else
        usable_height = height - (padding * 2)
        height - padding - (((value - minimum) / range) * usable_height)
      end

      "#{profile_svg_number(x)},#{profile_svg_number(y)}"
    end.join(" ")
  end

  def open_bean_cockpit_setup_parts(brew)
    return [] unless brew

    [
      open_bean_cockpit_grind_part(brew),
      open_bean_cockpit_ratio_part(brew),
      open_bean_cockpit_temperature_part(brew)
    ].compact
  end

  private
    def dashboard_format_duration(total_seconds)
      days = total_seconds / 86_400
      remaining = total_seconds % 86_400
      hours = remaining / 3_600
      remaining %= 3_600
      minutes = remaining / 60
      seconds = remaining % 60

      parts = []
      parts << "#{days}d" if days.positive?
      parts << "#{hours}h" if hours.positive? || parts.any?
      parts << "#{minutes}m" if minutes.positive? || parts.any?
      parts << "#{seconds}s"
      parts.join(" ")
    end

    def profile_svg_number(value)
      profile_number(value, precision: 2).tr(",", ".")
    end

    def open_bean_cockpit_grind_part(brew)
      return if brew.grind_setting.blank?

      t("workspaces.show.cockpit.grind", setting: brew.grind_setting)
    end

    def open_bean_cockpit_ratio_part(brew)
      ratio = brew_card_ratio_value(brew)
      return if ratio == t("brews.show.unknown")

      if brew.total_time_seconds.present?
        t("workspaces.show.cockpit.ratio_time", ratio:, time: brew_card_seconds(brew.total_time_seconds))
      else
        t("workspaces.show.cockpit.ratio", ratio:)
      end
    end

    def open_bean_cockpit_temperature_part(brew)
      return if brew.brew_temperature_celsius.blank?

      t("workspaces.show.cockpit.temperature", temperature: profile_temperature(brew.brew_temperature_celsius))
    end
end
