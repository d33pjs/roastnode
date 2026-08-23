module PublicBeanSharesHelper
  TIMELINE_CLUSTER_WINDOW_PERCENT = 4.0
  TIMELINE_ITEM_GAP_PERCENT = 5.5
  TIMELINE_LABEL_GAP_PERCENT = 28.0
  TIMELINE_LABEL_LANES_PER_SIDE = 3
  TIMELINE_MIN_POSITION_PERCENT = 8.0
  TIMELINE_MAX_POSITION_PERCENT = 82.0

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

  def public_bean_share_title(snapshot)
    snapshot ||= {}
    return snapshot["title"] if snapshot["title"].present?

    bean = snapshot["bean"] || {}
    type_fallback = [ bean["roast_type"], bean["blend_type"] ]
      .reject { |value| value == "unknown" }
      .compact_blank
      .map(&:humanize)
      .join(" · ")

    type_fallback.presence || t("public_bean_pages.show.share_title_missing")
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

    (((event_time - start_time) / duration) * 100).round(2).clamp(0, 100)
  rescue ArgumentError, TypeError
    0
  end

  def public_bean_timeline_items(timeline)
    timeline ||= {}
    brews = Array(timeline["brews"])
    return [] if brews.empty?

    events = brews.each_with_index.map do |brew, index|
      raw_position = public_bean_timeline_position(timeline["opened_on"], timeline["end_at"], brew["occurred_at"])
        .to_f
        .clamp(TIMELINE_MIN_POSITION_PERCENT, TIMELINE_MAX_POSITION_PERCENT)

      brew.merge(
        "_timeline_index" => index,
        "_timeline_time" => public_bean_time(brew["occurred_at"]),
        "raw_position" => raw_position.round(2)
      )
    end.sort_by { |event| [ event["_timeline_time"] || Time.zone.at(0), event["_timeline_index"] ] }

    groups = public_bean_timeline_groups(events)
    display_positions = public_bean_timeline_display_positions(
      groups.map { |group| public_bean_timeline_average_position(group) },
      gap: TIMELINE_ITEM_GAP_PERCENT
    )

    items = groups.each_with_index.map { |group, index| public_bean_timeline_item(group, display_positions[index]) }
    public_bean_timeline_assign_label_lanes(items)
  end

  def public_bean_timeline_item_label(item)
    first_time = public_bean_time(item["occurred_at"])
    last_time = public_bean_time(item["last_occurred_at"])
    return public_bean_unknown_label unless first_time

    if last_time && first_time.to_date != last_time.to_date
      "#{first_time.strftime("%b %-d")}-#{last_time.strftime("%b %-d")}"
    elsif item["type"] == "cluster"
      first_time.strftime("%b %-d %H:%M")
    else
      first_time.strftime("%b %-d")
    end
  end

  def public_bean_timeline_item_title(item)
    brews = Array(item["brews"]).presence || [ item ]
    rating_labels = brews.filter_map { |brew| public_bean_rating(brew["rating"]) if brew["rating"].present? }
    bylines = brews.map { |brew| public_bean_recipient_byline(brew["user"], brew["recipient"]) }.uniq
    parts = [
      item["type"] == "cluster" ? t("public_bean_pages.show.timeline_brews", count: item["count"]) : public_bean_method_label(item["method"]),
      public_bean_timeline_item_label(item),
      rating_labels.to_sentence,
      bylines.to_sentence
    ].compact_blank

    parts.join(" · ")
  end

  def public_bean_recipient_byline(logger, recipient)
    logger = logger.is_a?(Hash) ? logger : {}
    recipient = recipient.is_a?(Hash) ? recipient : {}
    target = case recipient["kind"]
    when "self"
      t("brews.recipients.themself")
    when "household_member"
      recipient["display_label"].presence || t("brews.recipients.a_household_member")
    when "guest"
      t("brews.recipients.a_guest")
    else
      t("brews.recipients.someone")
    end

    t(
      "brews.recipients.byline",
      logger: logger["display_label"].presence || public_bean_unknown_label,
      recipient: target
    )
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

    def public_bean_timeline_groups(events)
      events.each_with_object([]) do |event, groups|
        if groups.empty? || event.fetch("raw_position") - groups.last.last.fetch("raw_position") > TIMELINE_CLUSTER_WINDOW_PERCENT
          groups << [ event ]
        else
          groups.last << event
        end
      end
    end

    def public_bean_timeline_average_position(group)
      return 0 if group.empty?

      group.sum { |event| event.fetch("raw_position").to_d } / group.size
    end

    def public_bean_timeline_item(group, display_position)
      ratings = group.map { |event| event["rating"] }
      methods = group.map { |event| event["method"].presence || "unknown" }
      primary_method = methods.tally.max_by { |method, count| [ count, -methods.index(method) ] }&.first || "unknown"
      brews = group.map { |event| event.except("_timeline_index", "_timeline_time") }
      first = brews.first || {}
      last = brews.last || first

      first.merge(
        "type" => group.one? ? "brew" : "cluster",
        "count" => group.size,
        "brews" => brews,
        "ratings" => ratings,
        "methods" => methods,
        "primary_method" => primary_method,
        "raw_position" => public_bean_timeline_average_position(group).to_f.round(2),
        "display_position" => display_position.to_f.round(2),
        "last_occurred_at" => last["occurred_at"]
      )
    end

    def public_bean_timeline_assign_label_lanes(items)
      lane_positions = {
        "top" => Array.new(TIMELINE_LABEL_LANES_PER_SIDE) { -Float::INFINITY },
        "bottom" => Array.new(TIMELINE_LABEL_LANES_PER_SIDE) { -Float::INFINITY }
      }

      items.each_with_index.map do |item, index|
        position = item.fetch("display_position").to_f
        preferred_sides = index.even? ? %w[bottom top] : %w[top bottom]
        side, lane = public_bean_timeline_available_label_lane(position, lane_positions, preferred_sides)
        lane_positions.fetch(side)[lane] = position
        item.merge("label_side" => side, "label_lane" => lane)
      end
    end

    def public_bean_timeline_available_label_lane(position, lane_positions, preferred_sides)
      preferred_sides.each do |side|
        lane_positions.fetch(side).each_with_index do |last_position, lane|
          return [ side, lane ] if position - last_position >= TIMELINE_LABEL_GAP_PERCENT
        end
      end

      preferred_sides
        .flat_map { |side| lane_positions.fetch(side).each_with_index.map { |last_position, lane| [ side, lane, last_position ] } }
        .min_by { |side, lane, last_position| [ last_position, lane, preferred_sides.index(side) ] }
        .first(2)
    end

    def public_bean_timeline_display_positions(positions, gap:)
      positions = positions.map(&:to_f)
      return positions if positions.one?

      gap = [
        gap,
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
