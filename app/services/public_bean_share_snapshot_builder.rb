class PublicBeanShareSnapshotBuilder
  def initialize(bean:, title:, selected_photo_attachment_ids:)
    @bean = bean
    @title = title
    @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i).uniq
    @brews = bean.brews.includes(
      :workspace,
      :recipient_user,
      :grinder,
      :machine,
      :brewer,
      :public_brew_share,
      user: { avatar_attachment: :blob }
    ).order(occurred_at: :desc, created_at: :desc).to_a
  end

  def call
    payload = {
      "title" => title,
      "workspace" => workspace_payload,
      "bean" => bean_payload,
      "stats" => stats_payload,
      "comparisons" => BeanComparisonRanker.new(bean:).call,
      "distributions" => distributions_payload,
      "timeline" => timeline_payload,
      "photos" => photo_payloads,
      "brews" => brew_payloads,
      "generated_at" => time_string(Time.current)
    }
    payload["public_media"] = public_media_payloads(payload)
    payload
  end

  private
    attr_reader :bean, :title, :selected_photo_attachment_ids, :brews

    def workspace_payload
      {
        "name" => bean.workspace.name,
        "logo_attachment_id" => attachment_id(bean.workspace.logo.attachment)
      }
    end

    def bean_payload
      {
        "name" => bean.name,
        "display_name" => bean.display_name,
        "roaster_name" => bean.roaster_name,
        "origin" => bean.origin,
        "process" => bean.process,
        "roast_date" => bean.roast_date&.iso8601,
        "opened_on" => bean.opened_on&.iso8601,
        "roast_type" => bean.roast_type,
        "roast_level" => bean.roast_level,
        "roast_degree" => decimal_string(bean.roast_degree),
        "tasting_notes" => bean.tasting_notes,
        "public_note" => bean.public_note,
        "public_status" => bean.open? ? "open" : "finished",
        "bag_size_grams" => decimal_string(bean.bag_size_grams),
        "remaining_grams" => decimal_string(bean.remaining_grams),
        "remaining_percent" => bean.remaining_percent&.to_i,
        "decaffeinated" => bean.decaffeinated,
        "continent" => bean.continent,
        "country" => bean.country,
        "country_of_manufacturer" => bean.country_of_manufacturer,
        "manufacturer" => bean.manufacturer,
        "region" => bean.region,
        "farm" => bean.farm,
        "farmer" => bean.farmer,
        "elevation" => bean.elevation,
        "variety" => bean.variety,
        "harvested" => bean.harvested,
        "blend_type" => bean.blend_type,
        "blend_percentage" => bean.blend_percentage,
        "links" => link_payloads(bean)
      }
    end

    def stats_payload
      {
        "brew_count" => brews.size,
        "consumed_grams" => decimal_string(consumed_grams, precision: 1),
        "dead_grams" => decimal_string(dead_grams, precision: 1),
        "average_rating" => decimal_string(average_rating, precision: 1),
        "channeling_count" => channeling_count,
        "channeling_brew_count" => espresso_brews.size,
        "channeling_percent" => percentage(channeling_count, espresso_brews.size),
        "open_duration_days" => open_duration_days
      }
    end

    def distributions_payload
      {
        "rating" => count_by_present_value(brews.filter_map(&:rating).map(&:to_s)),
        "taste_balance" => count_by_present_value(brews.filter_map(&:taste_balance)),
        "grind_setting" => count_by_present_value(brews.filter_map(&:grind_setting))
      }
    end

    def timeline_payload
      last_brew = brews.first
      end_time = terminal_at || last_brew&.occurred_at || Time.current

      {
        "opened_on" => bean.opened_on&.iso8601,
        "finished_at" => time_string(terminal_at),
        "last_brew_at" => time_string(last_brew&.occurred_at),
        "end_at" => time_string(end_time),
        "brews" => brews.sort_by { |brew| [ brew.occurred_at, brew.created_at ] }.map do |brew|
          {
            "occurred_at" => time_string(brew.occurred_at),
            "method" => brew.method,
            "rating" => brew.rating,
            "user" => user_payload(brew.user),
            "recipient" => recipient_payload(brew)
          }
        end
      }
    end

    def photo_payloads
      selected_bean_photo_attachment_ids.map { |attachment_id| { "attachment_id" => attachment_id } }
    end

    def brew_payloads
      brews.map { |brew| brew_payload(brew) }
    end

    def brew_payload(brew)
      common_brew_payload(brew).merge(method_specific_brew_payload(brew))
    end

    def common_brew_payload(brew)
      payload = {
        "occurred_at" => time_string(brew.occurred_at),
        "method" => brew.method,
        "public_note" => brew.public_note,
        "bean_weight_grams" => decimal_string(brew.bean_weight_grams),
        "beverage_grams" => decimal_string(brew.beverage_grams),
        "grind_setting" => brew.grind_setting,
        "total_time_seconds" => brew.total_time_seconds,
        "taste_balance" => brew.taste_balance,
        "rating" => brew.rating,
        "user" => user_payload(brew.user),
        "recipient" => recipient_payload(brew),
        "equipment" => equipment_payloads(brew)
      }
      if (public_share = public_brew_share_payload(brew)).present?
        payload["public_share"] = public_share
      end
      payload
    end

    def method_specific_brew_payload(brew)
      if brew.espresso?
        espresso_brew_payload(brew)
      elsif brew.quick_drip?
        quick_drip_brew_payload(brew)
      else
        {}
      end
    end

    def espresso_brew_payload(brew)
      {
        "ground_weight_grams" => decimal_string(brew.ground_weight_grams),
        "dose_grams" => decimal_string(brew.dose_grams),
        "brew_temperature_celsius" => decimal_string(brew.brew_temperature_celsius),
        "preinfusion_seconds" => brew.preinfusion_seconds,
        "first_drip_seconds" => brew.first_drip_seconds,
        "channeling" => brew.channeling,
        "retention_marker" => brew.retention_marker
      }
    end

    def quick_drip_brew_payload(brew)
      {
        "machine_cups" => decimal_string(brew.machine_cups),
        "coffee_spoons" => decimal_string(brew.coffee_spoons),
        "grams_per_coffee_spoon" => decimal_string(brew.grams_per_coffee_spoon),
        "coffee_amount_source" => brew.coffee_amount_source
      }
    end

    def user_payload(user)
      {
        "display_label" => user.display_label,
        "avatar_attachment_id" => attachment_id(user.avatar.attachment)
      }
    end

    def recipient_payload(brew)
      @recipient_payloads ||= {}
      @recipient_payloads[brew.id] ||= PublicBrewRecipientProjection.new(
        brew:,
        authorized_recipient_user_ids:,
        recipient_avatar_attachment_ids:
      ).call
    end

    def authorized_recipient_user_ids
      @authorized_recipient_user_ids ||= begin
        ids = candidate_recipient_user_ids
        authorized_ids = ids.empty? ? [] : bean.workspace.memberships.where(user_id: ids).distinct.pluck(:user_id)
        authorized_ids.index_with(true)
      end
    end

    def recipient_avatar_attachment_ids
      @recipient_avatar_attachment_ids ||= begin
        ids = authorized_recipient_user_ids.keys
        if ids.empty?
          {}
        else
          ActiveStorage::Attachment
            .where(record_type: "User", record_id: ids, name: "avatar")
            .pluck(:record_id, :id)
            .to_h
        end
      end
    end

    def candidate_recipient_user_ids
      @candidate_recipient_user_ids ||= brews.filter_map do |brew|
        kind = brew.read_attribute_before_type_cast(:recipient_kind)
        brew.recipient_user_id if kind == "household_member" && brew.recipient_user_id
      end.uniq
    end

    def public_brew_share_payload(brew)
      share = brew.public_brew_share
      return unless brew.espresso? && share&.enabled?

      {
        "token" => share.token,
        "title" => share.title.presence || PublicBrewShare.default_title_for(brew)
      }
    end

    def equipment_payloads(brew)
      {
        "grinder" => equipment_payload(brew.grinder),
        "machine" => equipment_payload(brew.machine),
        "brewer" => equipment_payload(brew.brewer)
      }.compact
    end

    def equipment_payload(equipment)
      return unless equipment

      {
        "name" => equipment.name,
        "kind" => equipment.kind,
        "model" => equipment.model
      }
    end

    def link_payloads(record)
      record.record_links.publicly_visible.map do |link|
        {
          "label" => link.label,
          "url" => link.url,
          "kind" => link.kind,
          "position" => link.position
        }
      end
    end

    def public_media_payloads(payload)
      collect_attachment_ids(payload).map { |attachment_id| { "attachment_id" => attachment_id } }.uniq
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end

    def selected_bean_photo_attachment_ids
      @selected_bean_photo_attachment_ids ||= bean.photos.attachments.filter_map do |attachment|
        attachment.id if selected_photo_attachment_ids.include?(attachment.id)
      end
    end

    def consumed_grams
      brews.sum { |brew| brew.bean_weight_grams.to_d }
    end

    def dead_grams
      espresso_dead_grams + terminal_remaining_dead_grams
    end

    def espresso_dead_grams
      espresso_brews.sum do |brew|
        next 0.to_d if brew.bean_weight_grams.blank? || brew.ground_weight_grams.blank?

        [ brew.bean_weight_grams.to_d - brew.ground_weight_grams.to_d, 0.to_d ].max
      end
    end

    def terminal_remaining_dead_grams
      return 0.to_d unless (bean.finished? || bean.archived?) && bean.remaining_grams.present?

      [ bean.remaining_grams.to_d, 0.to_d ].max
    end

    def average_rating
      ratings = brews.filter_map(&:rating)
      return if ratings.empty?

      ratings.sum.to_d / ratings.size
    end

    def channeling_count
      espresso_brews.count(&:channeling?)
    end

    def espresso_brews
      @espresso_brews ||= brews.select(&:espresso?)
    end

    def percentage(part, whole)
      return 0 if whole.blank? || whole.to_d.zero?

      ((part.to_d / whole.to_d) * 100).round
    end

    def open_duration_days
      BeanOpenDuration.new(
        bean:,
        latest_brew_at: brews.filter_map(&:occurred_at).max
      ).call
    end

    def terminal_at
      bean.finished_at || bean.archived_at
    end

    def count_by_present_value(values)
      values.compact_blank.tally.sort_by { |label, count| [ -count, label ] }.to_h
    end

    def attachment_id(attachment)
      attachment&.id
    end

    def decimal_string(value, precision: nil)
      return if value.blank?

      decimal = value.to_d
      decimal = decimal.round(precision) if precision
      decimal.to_s("F")
    end

    def time_string(value)
      value&.utc&.iso8601
    end
end
