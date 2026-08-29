class PublicBrewShareSnapshotBuilder
  SNAPSHOT_KEYS = %w[title workspace user brew hero bean equipment tools photos generated_at public_media].freeze
  WORKSPACE_KEYS = %w[name logo_attachment_id].freeze
  USER_KEYS = %w[display_label avatar_attachment_id].freeze
  BREW_KEYS = %w[
    occurred_at method public_note bean_weight_grams ground_weight_grams dose_grams beverage_grams grind_setting
    brew_temperature_celsius total_time_seconds preinfusion_seconds first_drip_seconds channeling taste_balance rating
    retention_marker links recipient
  ].freeze
  HERO_KEYS = %w[bean_photo_attachment_id brew_photo_attachment_id].freeze
  BEAN_KEYS = %w[
    name display_name roaster_name origin process roast_date purchased_on opened_on roast_type roast_level roast_degree
    tasting_notes public_note photo_attachment_id photos links
  ].freeze
  EQUIPMENT_KEYS = %w[role name kind model public_note photo_attachment_id photos links].freeze
  TOOL_KEYS = %w[name brew_method position public_note photo_attachment_id photos links].freeze
  PHOTO_KEYS = %w[attachment_id].freeze
  LINK_KEYS = %w[label url kind position].freeze
  PUBLIC_MEDIA_KEYS = %w[attachment_id].freeze

  def initialize(brew:, title:, selected_photo_attachment_ids:)
    @brew = brew
    @title = title
    @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i).uniq
  end

  def call
    payload = {
      "title" => title.presence || default_title,
      "workspace" => workspace_payload,
      "user" => user_payload,
      "brew" => brew_payload.merge("recipient" => PublicBrewRecipientProjection.new(brew:).call),
      "hero" => {
        "bean_photo_attachment_id" => selected_primary_attachment_id(brew.bean),
        "brew_photo_attachment_id" => selected_primary_attachment_id(brew)
      }.compact,
      "bean" => bean_payload,
      "equipment" => [ equipment_payload(brew.grinder, "grinder"), equipment_payload(brew.machine, "machine") ].compact,
      "tools" => tool_payloads,
      "photos" => photo_payloads([ brew ]),
      "generated_at" => time_string(Time.current)
    }
    payload["public_media"] = public_media_payloads(payload)
    payload
  end

  private
    attr_reader :brew, :title, :selected_photo_attachment_ids

    def default_title
      PublicBrewShare.default_title_for(brew)
    end

    def workspace_payload
      {
        "name" => brew.workspace.name,
        "logo_attachment_id" => attachment_id(brew.workspace.logo.attachment)
      }
    end

    def user_payload
      {
        "display_label" => brew.user.display_label,
        "avatar_attachment_id" => attachment_id(brew.user.avatar.attachment)
      }
    end

    def brew_payload
      {
        "occurred_at" => time_string(brew.occurred_at),
        "method" => brew.method,
        "public_note" => brew.public_note,
        "bean_weight_grams" => decimal_string(brew.bean_weight_grams),
        "ground_weight_grams" => decimal_string(brew.ground_weight_grams),
        "dose_grams" => decimal_string(brew.dose_grams),
        "beverage_grams" => decimal_string(brew.beverage_grams),
        "grind_setting" => brew.grind_setting,
        "brew_temperature_celsius" => decimal_string(brew.brew_temperature_celsius),
        "total_time_seconds" => brew.total_time_seconds,
        "preinfusion_seconds" => brew.preinfusion_seconds,
        "first_drip_seconds" => brew.first_drip_seconds,
        "channeling" => brew.channeling,
        "taste_balance" => brew.taste_balance,
        "rating" => brew.rating,
        "retention_marker" => brew.retention_marker,
        "links" => link_payloads(brew)
      }
    end

    def bean_payload
      bean = brew.bean
      {
        "name" => bean.name,
        "display_name" => bean.display_name,
        "roaster_name" => bean.roaster_name,
        "origin" => bean.origin,
        "process" => bean.process,
        "roast_date" => bean.roast_date&.iso8601,
        "purchased_on" => bean.purchased_on&.iso8601,
        "opened_on" => bean.opened_on&.iso8601,
        "roast_type" => bean.roast_type,
        "roast_level" => bean.roast_level,
        "roast_degree" => decimal_string(bean.roast_degree),
        "tasting_notes" => bean.tasting_notes,
        "public_note" => bean.public_note,
        "photo_attachment_id" => selected_primary_attachment_id(bean),
        "photos" => photo_payloads([ bean ]),
        "links" => link_payloads(bean)
      }
    end

    def equipment_payload(equipment, role)
      return unless equipment

      {
        "role" => role,
        "name" => equipment.name,
        "kind" => equipment.kind,
        "model" => equipment.model,
        "public_note" => equipment.public_note,
        "photo_attachment_id" => selected_primary_attachment_id(equipment),
        "photos" => photo_payloads([ equipment ]),
        "links" => link_payloads(equipment)
      }
    end

    def tool_payloads
      brew.brew_preparation_tools.includes(:preparation_tool).order(:position).map do |snapshot|
        tool = snapshot.preparation_tool
        {
          "name" => snapshot.tool_name,
          "brew_method" => snapshot.brew_method,
          "position" => snapshot.position,
          "public_note" => tool&.public_note,
          "photo_attachment_id" => selected_primary_attachment_id(tool),
          "photos" => tool ? photo_payloads([ tool ]) : [],
          "links" => tool ? link_payloads(tool) : []
        }
      end
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

    def time_string(value)
      value&.utc&.iso8601
    end

    def photo_payloads(records)
      records.compact.flat_map do |record|
        record.photos.attachments.select { |attachment| selected_photo_attachment_ids.include?(attachment.id) }.map do |attachment|
          {
            "attachment_id" => attachment.id
          }
        end
      end
    end

    def selected_primary_attachment_id(record)
      attachment = record&.primary_photo_attachment
      return unless attachment && selected_photo_attachment_ids.include?(attachment.id)

      attachment.id
    end

    def attachment_id(attachment)
      attachment&.id
    end

    def public_media_payloads(payload)
      collect_attachment_ids(payload).map { |id| { "attachment_id" => id } }.uniq
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

    def decimal_string(value)
      value&.to_s
    end
end
