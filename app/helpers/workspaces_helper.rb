module WorkspacesHelper
  def open_bean_cockpit_setup_parts(brew)
    return [] unless brew

    [
      open_bean_cockpit_grind_part(brew),
      open_bean_cockpit_ratio_part(brew),
      open_bean_cockpit_temperature_part(brew)
    ].compact
  end

  private
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
