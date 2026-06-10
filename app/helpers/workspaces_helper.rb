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

  def dashboard_line_chart_points(source, width: 160, height: 72, padding_x: 8, padding_y: 8)
    dashboard_line_chart_coordinates(source, width:, height:, padding_x:, padding_y:)
      .map { |point| "#{point[:x]},#{point[:y]}" }
      .join(" ")
  end

  def dashboard_line_chart_area_points(source, width: 160, height: 72, padding_x: 8, padding_y: 8)
    points = dashboard_line_chart_points(source, width:, height:, padding_x:, padding_y:)
    return "" if points.blank?

    bottom = profile_svg_number(height - padding_y)
    left = profile_svg_number(padding_x)
    right = profile_svg_number(width - padding_x)
    "#{left},#{bottom} #{points} #{right},#{bottom}"
  end

  def dashboard_line_chart_baseline_y(source, width: 160, height: 72, padding_x: 8, padding_y: 8)
    return unless source.is_a?(Hash) && source[:baseline_average].present?

    _x, y = dashboard_line_chart_position(
      source[:baseline_average].to_d,
      0,
      source,
      width:,
      height:,
      padding_x:,
      padding_y:
    )
    profile_svg_number(y)
  end

  def dashboard_line_chart_current_point(source, width: 160, height: 72, padding_x: 8, padding_y: 8)
    point = dashboard_line_chart_coordinates(source, width:, height:, padding_x:, padding_y:).last
    return unless point

    { x: point[:x], y: point[:y] }
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

    def dashboard_line_chart_coordinates(source, width:, height:, padding_x:, padding_y:)
      values = dashboard_line_chart_values(source)
      return [] if values.empty?

      values.each_with_index.map do |value, index|
        x, y = dashboard_line_chart_position(value, index, source, width:, height:, padding_x:, padding_y:)
        { x: profile_svg_number(x), y: profile_svg_number(y) }
      end
    end

    def dashboard_line_chart_position(value, index, source, width:, height:, padding_x:, padding_y:)
      values = dashboard_line_chart_values(source)
      minimum = dashboard_line_chart_scale_value(source, :scale_min) || values.min
      maximum = dashboard_line_chart_scale_value(source, :scale_max) || values.max
      range = maximum - minimum
      x_step = values.one? ? 0 : (width - (padding_x * 2)).to_d / (values.size - 1)
      x = padding_x + (x_step * index)

      y = if range.zero?
        height.to_d / 2
      else
        clamped_value = [ [ value.to_d, minimum ].max, maximum ].min
        usable_height = height - (padding_y * 2)
        height - padding_y - (((clamped_value - minimum) / range) * usable_height)
      end

      [ x.round(2), y.round(2) ]
    end

    def dashboard_line_chart_values(source)
      raw_values = source.is_a?(Hash) ? source[:values] : source
      Array(raw_values).map(&:to_d)
    end

    def dashboard_line_chart_scale_value(source, key)
      return unless source.is_a?(Hash)
      return unless source.key?(key)

      source[key].to_d
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
