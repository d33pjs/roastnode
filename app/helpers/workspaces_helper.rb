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
