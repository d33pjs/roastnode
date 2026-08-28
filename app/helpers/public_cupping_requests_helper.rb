module PublicCuppingRequestsHelper
  CUPPING_TASTE_VALUES = %w[unknown very_sour sour neutral bitter very_bitter].freeze

  def cupping_countdown_deadline_value(cupping_request)
    (cupping_request.feedback_expires_at.to_f * 1000).round
  end

  def cupping_countdown_text(seconds)
    total_seconds = [ seconds.to_i, 0 ].max
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    remaining_seconds = total_seconds % 60

    format("%02d:%02d:%02d", hours, minutes, remaining_seconds)
  end

  def cupping_taste_options
    CUPPING_TASTE_VALUES.map do |value|
      [ value, t("public_cupping_requests.feedback.tastes.#{value}") ]
    end
  end

  def public_snapshot_taste_label(value)
    t(
      "public_brew_pages.show.tastes.#{value.presence || "unknown"}",
      default: t("public_brew_pages.show.unknown")
    )
  end
end
