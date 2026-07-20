class WorkspaceExportBuilder
  FORMAT = "roastnode.workspace_export"
  VERSION = 1

  def initialize(workspace, generated_at: Time.current)
    @workspace = workspace
    @generated_at = generated_at
  end

  def call
    {
      format: FORMAT,
      version: VERSION,
      generated_at: timestamp(generated_at),
      workspace: workspace_payload,
      memberships: memberships_payload,
      data_imports: data_imports_payload,
      beans: beans_payload,
      equipment: equipment_payload,
      preparation_tools: preparation_tools_payload,
      brews: brews_payload,
      external_coffees: external_coffees_payload,
      brew_preparation_tools: brew_preparation_tools_payload,
      equipment_events: equipment_events_payload,
      equipment_event_items: equipment_event_items_payload,
      inventory_adjustments: inventory_adjustments_payload
    }
  end

  private
    attr_reader :workspace, :generated_at

    def workspace_payload
      {
        id: workspace.id,
        name: workspace.name,
        kind: workspace.kind,
        default_currency: workspace.default_currency,
        created_at: timestamp(workspace.created_at),
        updated_at: timestamp(workspace.updated_at)
      }
    end

    def memberships_payload
      workspace.memberships.includes(:user).order(:id).map do |membership|
        {
          id: membership.id,
          user_id: membership.user_id,
          email_address: membership.user.email_address,
          display_name: membership.user.display_name,
          role: membership.role,
          created_at: timestamp(membership.created_at),
          updated_at: timestamp(membership.updated_at)
        }
      end
    end

    def beans_payload
      workspace.beans.order(:id).map do |bean|
        {
          id: bean.id,
          name: bean.name,
          roaster_name: bean.roaster_name,
          origin: bean.origin,
          process: bean.process,
          roast_date: date(bean.roast_date),
          roast_level: bean.roast_level,
          roast_type: bean.roast_type,
          grind_state: bean.grind_state,
          roast_degree: decimal(bean.roast_degree),
          tasting_notes: bean.tasting_notes,
          status: bean.bag_status,
          bag_size_grams: decimal(bean.bag_size_grams),
          remaining_grams: decimal(bean.remaining_grams),
          opened_on: date(bean.opened_on),
          finished_at: timestamp(bean.finished_at),
          archived_at: timestamp(bean.archived_at),
          blend_type: bean.blend_type,
          decaffeinated: bean.decaffeinated,
          purchase_source: bean.purchase_source,
          purchase_url: bean.purchase_url,
          purchased_on: date(bean.purchased_on),
          purchase_price_cents: bean.purchase_price_cents,
          rating: bean.rating,
          primary_photo_attachment_id: bean.primary_photo_attachment_id,
          continent: bean.continent,
          country: bean.country,
          country_of_manufacturer: bean.country_of_manufacturer,
          manufacturer: bean.manufacturer,
          region: bean.region,
          farm: bean.farm,
          farmer: bean.farmer,
          elevation: bean.elevation,
          variety: bean.variety,
          harvested: bean.harvested,
          blend_percentage: bean.blend_percentage,
          notes: bean.notes,
          created_at: timestamp(bean.created_at),
          updated_at: timestamp(bean.updated_at),
          data_import_id: bean.data_import_id,
          import_source: bean.import_source,
          import_source_id: bean.import_source_id,
          duplicated_from_bean_id: bean.duplicated_from_bean_id,
          raw_import_data: bean.raw_import_data,
          photos: photo_metadata(bean)
        }
      end
    end

    def data_imports_payload
      workspace.data_imports.includes(:user).order(:id).map do |data_import|
        {
          id: data_import.id,
          user_id: data_import.user_id,
          user_email_address: data_import.user.email_address,
          source: data_import.source,
          status: data_import.status,
          summary: data_import.summary,
          warnings: data_import.warnings,
          created_at: timestamp(data_import.created_at),
          updated_at: timestamp(data_import.updated_at)
        }
      end
    end

    def equipment_payload
      workspace.equipment.order(:id).map do |item|
        {
          id: item.id,
          name: item.name,
          kind: item.kind,
          model: item.model,
          preinfusion_enabled: item.preinfusion_enabled,
          low_flow_start_enabled: item.low_flow_start_enabled,
          flow_control_enabled: item.flow_control_enabled,
          notes: item.notes,
          archived_at: timestamp(item.archived_at),
          primary_photo_attachment_id: item.primary_photo_attachment_id,
          created_at: timestamp(item.created_at),
          updated_at: timestamp(item.updated_at),
          data_import_id: item.data_import_id,
          import_source: item.import_source,
          import_source_id: item.import_source_id,
          raw_import_data: item.raw_import_data,
          photos: photo_metadata(item)
        }
      end
    end

    def preparation_tools_payload
      workspace.preparation_tools.order(:id).map do |tool|
        {
          id: tool.id,
          name: tool.name,
          brew_method: tool.brew_method,
          active: tool.active,
          position: tool.position,
          notes: tool.notes,
          primary_photo_attachment_id: tool.primary_photo_attachment_id,
          created_at: timestamp(tool.created_at),
          updated_at: timestamp(tool.updated_at),
          data_import_id: tool.data_import_id,
          import_source: tool.import_source,
          import_source_id: tool.import_source_id,
          raw_import_data: tool.raw_import_data,
          photos: photo_metadata(tool)
        }
      end
    end

    def brews_payload
      workspace.brews.includes(:user).order(:id).map do |brew|
        {
          id: brew.id,
          user_id: brew.user_id,
          user_email_address: brew.user.email_address,
          bean_id: brew.bean_id,
          grinder_id: brew.grinder_id,
          machine_id: brew.machine_id,
          brewer_id: brew.brewer_id,
          method: brew.method,
          occurred_at: timestamp(brew.occurred_at),
          bean_weight_grams: decimal(brew.bean_weight_grams),
          ground_weight_grams: decimal(brew.ground_weight_grams),
          dose_grams: decimal(brew.dose_grams),
          beverage_grams: decimal(brew.beverage_grams),
          machine_cups: decimal(brew.machine_cups),
          coffee_spoons: decimal(brew.coffee_spoons),
          grams_per_coffee_spoon: decimal(brew.grams_per_coffee_spoon),
          coffee_amount_source: brew.coffee_amount_source,
          grind_setting: brew.grind_setting,
          brew_temperature_celsius: decimal(brew.brew_temperature_celsius),
          total_time_seconds: brew.total_time_seconds,
          preinfusion_seconds: brew.preinfusion_seconds,
          low_flow_start_seconds: brew.low_flow_start_seconds,
          first_drip_seconds: brew.first_drip_seconds,
          channeling: brew.channeling,
          flow_control_used: brew.flow_control_used,
          taste_balance: brew.taste_balance,
          rating: brew.rating,
          served_for_guest: brew.served_for_guest,
          guest_name: brew.guest_name,
          cup_style: brew.cup_style,
          notes: brew.notes,
          retention_marker: brew.retention_marker,
          primary_photo_attachment_id: brew.primary_photo_attachment_id,
          created_at: timestamp(brew.created_at),
          updated_at: timestamp(brew.updated_at),
          data_import_id: brew.data_import_id,
          import_source: brew.import_source,
          import_source_id: brew.import_source_id,
          raw_import_data: brew.raw_import_data,
          photos: photo_metadata(brew)
        }
      end
    end

    def brew_preparation_tools_payload
      BrewPreparationTool.where(brew_id: workspace.brews.select(:id)).order(:brew_id, :position, :id).map do |tool|
        {
          id: tool.id,
          brew_id: tool.brew_id,
          preparation_tool_id: tool.preparation_tool_id,
          tool_name: tool.tool_name,
          brew_method: tool.brew_method,
          position: tool.position,
          created_at: timestamp(tool.created_at),
          updated_at: timestamp(tool.updated_at)
        }
      end
    end

    def external_coffees_payload
      workspace.external_coffees.includes(:user).order(:id).map do |coffee|
        {
          id: coffee.id,
          user_id: coffee.user_id,
          user_email_address: coffee.user.email_address,
          occurred_at: timestamp(coffee.occurred_at),
          drink_type: coffee.drink_type,
          drink_size: coffee.drink_size,
          place_name: coffee.place_name,
          place_location: coffee.place_location,
          latitude: decimal(coffee.latitude),
          longitude: decimal(coffee.longitude),
          price_cents: coffee.price_cents,
          currency: coffee.currency,
          acidity_balance: coffee.acidity_balance,
          intensity: coffee.intensity,
          rating: coffee.rating,
          notes: coffee.notes,
          public_note: coffee.public_note,
          primary_photo_attachment_id: coffee.primary_photo_attachment_id,
          created_at: timestamp(coffee.created_at),
          updated_at: timestamp(coffee.updated_at),
          photos: photo_metadata(coffee)
        }
      end
    end

    def equipment_events_payload
      workspace.equipment_events.includes(:user).order(:id).map do |event|
        {
          id: event.id,
          user_id: event.user_id,
          user_email_address: event.user.email_address,
          event_type: event.event_type,
          event_types: event.event_types,
          occurred_at: timestamp(event.occurred_at),
          notes: event.notes,
          primary_photo_attachment_id: event.primary_photo_attachment_id,
          created_at: timestamp(event.created_at),
          updated_at: timestamp(event.updated_at),
          photos: photo_metadata(event)
        }
      end
    end

    def equipment_event_items_payload
      EquipmentEventItem.where(equipment_event_id: workspace.equipment_events.select(:id)).order(:equipment_event_id, :equipment_id).map do |item|
        {
          id: item.id,
          equipment_event_id: item.equipment_event_id,
          equipment_id: item.equipment_id,
          created_at: timestamp(item.created_at),
          updated_at: timestamp(item.updated_at)
        }
      end
    end

    def inventory_adjustments_payload
      workspace.inventory_adjustments.includes(:user).order(:id).map do |adjustment|
        {
          id: adjustment.id,
          bean_id: adjustment.bean_id,
          brew_id: adjustment.brew_id,
          user_id: adjustment.user_id,
          user_email_address: adjustment.user.email_address,
          delta_grams: decimal(adjustment.delta_grams),
          reason: adjustment.reason,
          note: adjustment.note,
          occurred_at: timestamp(adjustment.occurred_at),
          created_at: timestamp(adjustment.created_at),
          updated_at: timestamp(adjustment.updated_at)
        }
      end
    end

    def photo_metadata(record)
      record.photos.attachments.includes(:blob).order(:id).map do |attachment|
        {
          attachment_id: attachment.id,
          name: attachment.name,
          filename: attachment.blob.filename.to_s,
          content_type: attachment.blob.content_type,
          byte_size: attachment.blob.byte_size,
          checksum: attachment.blob.checksum,
          created_at: timestamp(attachment.created_at)
        }
      end
    end

    def decimal(value)
      value&.to_s("F")
    end

    def timestamp(value)
      value&.iso8601
    end

    def date(value)
      value&.iso8601
    end
end
