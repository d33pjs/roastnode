module PublicBeanSharesHelper
  TIMELINE_CLUSTER_GAP_PERCENT = 4.0
  TIMELINE_MIN_POSITION_PERCENT = 6.0
  TIMELINE_MAX_POSITION_PERCENT = 94.0

  def public_bean_media_url_for(share, attachment_id, variant: nil)
    return if attachment_id.blank?

    media_handle = share.public_media_handle_for(attachment_id)
    return if media_handle.blank?

    public_bean_media_path(share.token, media_handle, variant:)
  end

  def public_bean_grams(value)
    return public_bean_unknown_label if value.blank?

    "#{public_bean_decimal(value)}g"
  end

  def public_bean_seconds(value)
    return public_bean_unknown_label if value.blank?

    "#{value}s"
  end

  def public_bean_percent(value)
    return public_bean_unknown_label if value.blank?

    "#{value}%"
  end

  def public_bean_rating(value)
    return public_bean_unknown_label if value.blank?

    "#{public_bean_decimal(value)}/5"
  end

  def public_bean_ratio(brew)
    dose = public_bean_decimal_value(brew["dose_grams"].presence || brew["bean_weight_grams"])
    beverage = public_bean_decimal_value(brew["beverage_grams"])
    return public_bean_unknown_label if dose.zero? || beverage.zero?

    "1:#{public_bean_decimal(beverage / dose, precision: 2)}"
  end

  def public_bean_date(value)
    date = Date.iso8601(value.to_s)
    l(date, format: :long)
  rescue ArgumentError, TypeError
    nil
  end

  def public_bean_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def public_bean_timeline_position(opened_on, end_at, occurred_at)
    return 0 if opened_on.blank? || end_at.blank? || occurred_at.blank?

    start_time = Time.zone.parse(opened_on.to_s)
    end_time = Time.zone.parse(end_at.to_s)
    event_time = Time.zone.parse(occurred_at.to_s)
    duration = end_time - start_time
    return 0 if duration <= 0

    (((event_time - start_time) / duration) * 100).round.clamp(0, 100)
  rescue ArgumentError, TypeError
    0
  end

  def public_bean_timeline_events(timeline)
    timeline ||= {}
    brews = Array(timeline["brews"])
    return [] if brews.empty?

    positions = brews.map do |brew|
      public_bean_timeline_position(timeline["opened_on"], timeline["end_at"], brew["occurred_at"])
        .to_f
        .clamp(TIMELINE_MIN_POSITION_PERCENT, TIMELINE_MAX_POSITION_PERCENT)
    end
    display_positions = public_bean_timeline_display_positions(positions)

    lane_counts = Hash.new(0)

    brews.each_with_index.map do |brew, index|
      callout_side = index.even? ? "top" : "bottom"
      callout_lane = [ lane_counts[callout_side], 2 ].min
      lane_counts[callout_side] += 1

      brew.merge(
        "raw_position" => positions[index].round(2),
        "display_position" => display_positions[index].round(2),
        "callout_side" => callout_side,
        "callout_lane" => callout_lane
      )
    end
  end

  def public_bean_link_label(link)
    link["label"].presence || t("public_bean_pages.show.#{link["kind"].presence || "info"}", default: t("public_bean_pages.show.info"))
  end

  def public_bean_method_label(method)
    case method
    when "quick_drip"
      t("public_bean_pages.show.quick_drip")
    when "espresso"
      t("public_bean_pages.show.espresso")
    else
      method.to_s.humanize.presence || public_bean_unknown_label
    end
  end

  private
    def public_bean_unknown_label
      t("public_bean_pages.show.unknown")
    end

    def public_bean_decimal(value, precision: 1)
      number_with_precision(
        value.to_d,
        precision:,
        strip_insignificant_zeros: true,
        separator: ".",
        delimiter: ","
      )
    end

    def public_bean_decimal_value(value)
      return 0.to_d if value.blank?

      value.to_d
    end

    def public_bean_timeline_display_positions(positions)
      return positions if positions.one?

      gap = [
        TIMELINE_CLUSTER_GAP_PERCENT,
        (TIMELINE_MAX_POSITION_PERCENT - TIMELINE_MIN_POSITION_PERCENT) / (positions.size - 1)
      ].min

      separated = positions.each_with_index.map do |position, index|
        next position if index.zero?

        [ position, positions[index - 1] + gap ].max
      end

      separated.each_index do |index|
        next if index.zero?

        separated[index] = [ separated[index], separated[index - 1] + gap ].max
      end

      overflow = separated.last - TIMELINE_MAX_POSITION_PERCENT
      separated.map! { |position| position - overflow } if overflow.positive?

      if separated.first < TIMELINE_MIN_POSITION_PERCENT
        separated[0] = TIMELINE_MIN_POSITION_PERCENT
        (1...separated.size).each do |index|
          separated[index] = [ separated[index], separated[index - 1] + gap ].max
        end
      end

      separated.map { |position| position.clamp(TIMELINE_MIN_POSITION_PERCENT, TIMELINE_MAX_POSITION_PERCENT) }
    end
end
