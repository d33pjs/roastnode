class InstanceBackupRestorer
  class RestoreError < StandardError; end

  ACTIVITY_SUBJECT_MAPS = {
    "User" => :@user_map,
    "Workspace" => :@workspace_map,
    "Membership" => :@membership_map,
    "WorkspaceInvite" => :@workspace_invite_map,
    "DataImport" => :@data_import_map,
    "Bean" => :@bean_map,
    "Equipment" => :@equipment_map,
    "PreparationTool" => :@preparation_tool_map,
    "Brew" => :@brew_map,
    "ExternalCoffee" => :@external_coffee_map,
    "EquipmentEvent" => :@equipment_event_map,
    "InventoryAdjustment" => :@inventory_adjustment_map
  }.freeze

  def initialize(archive_source)
    @archive_bytes = InstanceBackupArchiveValidator.archive_bytes_for(archive_source)
    @user_map = {}
    @workspace_map = {}
    @membership_map = {}
    @workspace_invite_map = {}
    @data_import_map = {}
    @bean_map = {}
    @equipment_map = {}
    @preparation_tool_map = {}
    @brew_map = {}
    @external_coffee_map = {}
    @equipment_event_map = {}
    @inventory_adjustment_map = {}
    @cupping_request_map = {}
    @attachment_map = {}
    @active_workspace_targets = {}
    @bean_remaining_grams = {}
  end

  def call
    validation = InstanceBackupArchiveValidator.new(archive_bytes).call
    raise RestoreError, validation.errors.to_sentence unless validation.valid?
    raise RestoreError, "Target instance must be empty before restore." unless empty_instance?

    @payload = validation.payload
    @media_files = validation.media_files

    ActiveRecord::Base.transaction do
      restore_users
      restore_workspaces
      restore_memberships
      restore_workspace_invites
      restore_data_imports
      restore_beans
      restore_bean_duplicate_sources
      restore_equipment
      restore_preparation_tools
      restore_brews
      restore_cupping_requests
      restore_external_coffees
      restore_brew_preparation_tools
      restore_equipment_events
      restore_inventory_adjustments
      restore_media_files
      restore_cupping_request_snapshots
      restore_primary_photos
      restore_active_workspaces
      restore_activity_events
      reset_exported_bean_inventory
    end

    schedule_restored_cupping_expirations

    summary
  end

  private
    attr_reader :archive_bytes, :payload, :media_files

    def empty_instance?
      [
        ActivityEvent,
        InstanceBackupRun,
        InstanceBackupProfile,
        User,
        Workspace,
        Membership,
        WorkspaceInvite,
        DataImport,
        Bean,
        Equipment,
        PreparationTool,
        Brew,
        CuppingRequest,
        ExternalCoffee,
        BrewPreparationTool,
        EquipmentEvent,
        EquipmentEventItem,
        InventoryAdjustment,
        PasskeyCredential,
        ActiveStorage::Attachment,
        ActiveStorage::Blob
      ].none?(&:exists?)
    end

    def restore_users
      payload.fetch("users").each do |row|
        user = User.create!(
          email_address: row.fetch("email_address"),
          password: SecureRandom.urlsafe_base64(32),
          display_name: row["display_name"],
          instance_admin: row["instance_admin"],
          default_landing_screen: row["default_landing_screen"],
          default_brew_focus_field: row["default_brew_focus_field"],
          hidden_brew_field_names: row["hidden_brew_field_names"],
          enabled_brew_methods: row["enabled_brew_methods"].presence || %w[espresso quick_drip],
          grams_per_coffee_spoon: row["grams_per_coffee_spoon"],
          number_format: row["number_format"],
          time_format: row["time_format"],
          theme: row["theme"],
          created_at: time(row["created_at"]),
          updated_at: time(row["updated_at"])
        )
        @user_map[old_id(row)] = user
        @active_workspace_targets[user.id] = row["active_workspace_id"]
      end
    end

    def restore_workspaces
      workspace_payloads.each do |workspace_payload|
        row = workspace_payload.fetch("workspace")
        workspace = Workspace.create!(
          name: row.fetch("name"),
          kind: row["kind"],
          default_currency: row["default_currency"],
          created_at: time(row["created_at"]),
          updated_at: time(row["updated_at"])
        )
        @workspace_map[old_id(row)] = workspace
      end
    end

    def restore_memberships
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("memberships").each do |row|
          membership = Membership.create!(
            workspace:,
            user: @user_map.fetch(row.fetch("user_id")),
            role: row.fetch("role"),
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @membership_map[old_id(row)] = membership
        end
      end
    end

    def restore_workspace_invites
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        Array(workspace_payload["workspace_invites"]).each do |row|
          invite = WorkspaceInvite.create!(
            workspace:,
            created_by: @user_map.fetch(row.fetch("created_by_id")),
            accepted_by: optional_lookup(@user_map, row["accepted_by_id"]),
            email_address: row["email_address"],
            role: row.fetch("role"),
            expires_at: time(row["expires_at"]),
            revoked_at: time(row["revoked_at"]),
            accepted_at: time(row["accepted_at"]),
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @workspace_invite_map[old_id(row)] = invite
        end
      end
    end

    def restore_data_imports
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("data_imports").each do |row|
          data_import = DataImport.create!(
            workspace:,
            user: @user_map.fetch(row.fetch("user_id")),
            source: row.fetch("source"),
            status: row.fetch("status"),
            summary: row["summary"] || {},
            warnings: row["warnings"] || [],
            raw_payload: row["raw_payload"] || {},
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @data_import_map[old_id(row)] = data_import
        end
      end
    end

    def restore_beans
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("beans").each do |row|
          bean = Bean.create!(
            workspace:,
            data_import: optional_lookup(@data_import_map, row["data_import_id"]),
            name: row.fetch("name"),
            roaster_name: row["roaster_name"],
            origin: row["origin"],
            process: row["process"],
            roast_date: date(row["roast_date"]),
            roast_level: row["roast_level"],
            roast_type: row["roast_type"],
            grind_state: row["grind_state"].presence || "whole_bean",
            roast_degree: row["roast_degree"],
            tasting_notes: row["tasting_notes"],
            bag_size_grams: row["bag_size_grams"],
            remaining_grams: row["remaining_grams"],
            opened_on: date(row["opened_on"]),
            finished_at: time(row["finished_at"]),
            archived_at: time(row["archived_at"]),
            blend_type: row["blend_type"],
            decaffeinated: row["decaffeinated"],
            purchase_source: row["purchase_source"],
            purchase_url: Bean.safe_http_url(row["purchase_url"]),
            coffee_origin_url: Bean.safe_http_url(row["coffee_origin_url"]),
            purchased_on: date(row["purchased_on"]),
            purchase_price_cents: row["purchase_price_cents"],
            rating: [ 0, "0" ].include?(row["rating"]) ? nil : row["rating"],
            continent: row["continent"],
            country: row["country"],
            country_of_manufacturer: row["country_of_manufacturer"],
            manufacturer: row["manufacturer"],
            region: row["region"],
            farm: row["farm"],
            farmer: row["farmer"],
            elevation: row["elevation"],
            variety: row["variety"],
            harvested: row["harvested"],
            blend_percentage: row["blend_percentage"],
            notes: row["notes"],
            import_source: row["import_source"],
            import_source_id: row["import_source_id"],
            raw_import_data: row["raw_import_data"] || {},
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @bean_map[old_id(row)] = bean
          @bean_remaining_grams[old_id(row)] = row["remaining_grams"]
        end
      end
    rescue ActiveRecord::RecordInvalid, KeyError, ArgumentError
      raise RestoreError, "Invalid bean data"
    end

    def restore_bean_duplicate_sources
      workspace_payloads.each do |workspace_payload|
        workspace_payload.fetch("beans").each do |row|
          source_id = row["duplicated_from_bean_id"]
          next if source_id.blank?

          @bean_map.fetch(old_id(row)).update!(duplicated_from_bean: @bean_map.fetch(source_id))
        end
      end
    end

    def restore_equipment
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("equipment").each do |row|
          equipment = Equipment.create!(
            workspace:,
            data_import: optional_lookup(@data_import_map, row["data_import_id"]),
            name: row.fetch("name"),
            kind: row.fetch("kind"),
            model: row["model"],
            preinfusion_enabled: row.fetch("preinfusion_enabled", row.fetch("kind") == "machine"),
            low_flow_start_enabled: row.fetch("low_flow_start_enabled", false),
            flow_control_enabled: row.fetch("flow_control_enabled", false),
            notes: row["notes"],
            archived_at: time(row["archived_at"]),
            import_source: row["import_source"],
            import_source_id: row["import_source_id"],
            raw_import_data: row["raw_import_data"] || {},
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @equipment_map[old_id(row)] = equipment
        end
      end
    end

    def restore_preparation_tools
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("preparation_tools").each do |row|
          tool = PreparationTool.create!(
            workspace:,
            data_import: optional_lookup(@data_import_map, row["data_import_id"]),
            name: row.fetch("name"),
            brew_method: row["brew_method"],
            active: row["active"],
            position: row["position"],
            notes: row["notes"],
            import_source: row["import_source"],
            import_source_id: row["import_source_id"],
            raw_import_data: row["raw_import_data"] || {},
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          tool.update_column(:position, row["position"]) if row["position"]
          @preparation_tool_map[old_id(row)] = tool
        end
      end
    end

    def restore_brews
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("brews").each do |row|
          logger = @user_map.fetch(row.fetch("user_id"))
          brew = Brew.create!(
            workspace:,
            user: logger,
            bean: @bean_map.fetch(row.fetch("bean_id")),
            grinder: optional_lookup(@equipment_map, row["grinder_id"]),
            machine: optional_lookup(@equipment_map, row["machine_id"]),
            brewer: optional_lookup(@equipment_map, row["brewer_id"]),
            data_import: optional_lookup(@data_import_map, row["data_import_id"]),
            method: row["method"],
            occurred_at: time(row["occurred_at"]),
            bean_weight_grams: row["bean_weight_grams"],
            ground_weight_grams: row["ground_weight_grams"],
            dose_grams: row["dose_grams"],
            beverage_grams: row["beverage_grams"],
            machine_cups: row["machine_cups"],
            coffee_spoons: row["coffee_spoons"],
            grams_per_coffee_spoon: row["grams_per_coffee_spoon"],
            coffee_amount_source: row["coffee_amount_source"] || "measured",
            grind_setting: row["grind_setting"],
            brew_temperature_celsius: row["brew_temperature_celsius"],
            total_time_seconds: row["total_time_seconds"],
            preinfusion_seconds: row["preinfusion_seconds"],
            low_flow_start_seconds: row["low_flow_start_seconds"],
            first_drip_seconds: row["first_drip_seconds"],
            channeling: row["channeling"],
            flow_control_used: row["flow_control_used"],
            taste_balance: row["taste_balance"],
            rating: row["rating"],
            recipient_kind: "self",
            cup_style: restored_cup_style(row),
            notes: row["notes"],
            retention_marker: row["retention_marker"],
            import_source: row["import_source"],
            import_source_id: row["import_source_id"],
            raw_import_data: row["raw_import_data"] || {},
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          brew.inventory_adjustment&.destroy!
          brew.update_columns(coffee_amount_source: row["coffee_amount_source"]) if row["coffee_amount_source"].present?
          restore_brew_recipient!(brew, row, logger:)
          @brew_map[old_id(row)] = brew
        end
      end
    end

    def restore_brew_preparation_tools
      workspace_payloads.each do |workspace_payload|
        workspace_payload.fetch("brew_preparation_tools").each do |row|
          BrewPreparationTool.create!(
            brew: @brew_map.fetch(row.fetch("brew_id")),
            preparation_tool: optional_lookup(@preparation_tool_map, row["preparation_tool_id"]),
            tool_name: row.fetch("tool_name"),
            brew_method: row["brew_method"],
            position: row["position"],
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
        end
      end
    end

    def restore_cupping_requests
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        Array(workspace_payload["cupping_requests"]).each do |row|
          brew = @brew_map.fetch(row.fetch("brew_id"))
          unless row.fetch("workspace_id") == old_id(workspace_payload.fetch("workspace")) && brew.workspace == workspace
            invalid_cupping_request_data!
          end

          request = CuppingRequest.create!(
            workspace:,
            brew:,
            token: row.fetch("token"),
            token_digest: row.fetch("token_digest"),
            snapshot: row.fetch("snapshot").deep_dup,
            feedback_comment: row["feedback_comment"],
            opened_at: time(row["opened_at"]),
            feedback_expires_at: time(row["feedback_expires_at"]),
            closed_at: time(row["closed_at"]),
            last_guest_ip: row["last_guest_ip"],
            expiration_job_enqueued_at: time(row["expiration_job_enqueued_at"]),
            expiration_job_enqueueing_at: time(row["expiration_job_enqueueing_at"]),
            created_at: time(row.fetch("created_at")),
            updated_at: time(row.fetch("updated_at"))
          )
          unless request.token_digest == row.fetch("token_digest") && request.eligible?
            invalid_cupping_request_data!
          end

          @cupping_request_map[old_id(row)] = request
        end
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, KeyError, ArgumentError
      invalid_cupping_request_data!
    end

    def restore_external_coffees
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        Array(workspace_payload["external_coffees"]).each do |row|
          coffee = ExternalCoffee.create!(
            workspace:,
            user: @user_map.fetch(row.fetch("user_id")),
            occurred_at: time(row["occurred_at"]),
            drink_type: row.fetch("drink_type"),
            drink_size: row["drink_size"],
            place_name: row["place_name"],
            place_location: row["place_location"],
            latitude: row["latitude"],
            longitude: row["longitude"],
            price_cents: row["price_cents"],
            currency: row["currency"],
            acidity_balance: row["acidity_balance"] || "unknown",
            intensity: row["intensity"] || "unknown",
            rating: row["rating"],
            notes: row["notes"],
            public_note: row["public_note"],
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @external_coffee_map[old_id(row)] = coffee
        end
      end
    end

    def restore_equipment_events
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        equipment_by_event_id = Array(workspace_payload["equipment_event_items"]).group_by { |row| row.fetch("equipment_event_id") }
        workspace_payload.fetch("equipment_events").each do |row|
          equipment = Array(equipment_by_event_id[row.fetch("id")]).map { |item| @equipment_map.fetch(item.fetch("equipment_id")) }
          event = EquipmentEvent.new(
            workspace:,
            user: @user_map.fetch(row.fetch("user_id")),
            event_type: row.fetch("event_type"),
            event_types: row["event_types"],
            occurred_at: time(row["occurred_at"]),
            notes: row["notes"],
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          event.equipment = equipment
          event.save!
          @equipment_event_map[old_id(row)] = event
        end
      end
    end

    def restore_inventory_adjustments
      workspace_payloads.each do |workspace_payload|
        workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
        workspace_payload.fetch("inventory_adjustments").each do |row|
          adjustment = InventoryAdjustment.create!(
            workspace:,
            bean: @bean_map.fetch(row.fetch("bean_id")),
            brew: optional_lookup(@brew_map, row["brew_id"]),
            user: @user_map.fetch(row.fetch("user_id")),
            delta_grams: row.fetch("delta_grams"),
            reason: row.fetch("reason"),
            note: row["note"],
            occurred_at: time(row["occurred_at"]),
            created_at: time(row["created_at"]),
            updated_at: time(row["updated_at"])
          )
          @inventory_adjustment_map[old_id(row)] = adjustment
        end
      end
    end

    def restore_media_files
      Zip::File.open_buffer(archive_bytes) do |zip|
        media_files.each do |entry|
          record = restored_record_for(entry)
          next unless record

          attachment_name = entry.fetch("attachment_name")
          record.public_send(attachment_name).attach(
            io: StringIO.new(zip.read(entry.fetch("path"))),
            filename: entry.fetch("filename"),
            content_type: entry["content_type"]
          )
          new_attachment = restored_attachment(record, attachment_name)
          new_attachment.update_columns(created_at: time(entry["created_at"])) if entry["created_at"]
          @attachment_map[entry.fetch("attachment_id")] = new_attachment
        end
      end
    end

    def restore_primary_photos
      workspace_payloads.each do |workspace_payload|
        restore_primary_photo_ids(workspace_payload.fetch("beans"), @bean_map)
        restore_primary_photo_ids(workspace_payload.fetch("equipment"), @equipment_map)
        restore_primary_photo_ids(workspace_payload.fetch("preparation_tools"), @preparation_tool_map)
        restore_primary_photo_ids(workspace_payload.fetch("brews"), @brew_map)
        restore_primary_photo_ids(Array(workspace_payload["external_coffees"]), @external_coffee_map)
        restore_primary_photo_ids(workspace_payload.fetch("equipment_events"), @equipment_event_map)
      end
    end

    def restore_cupping_request_snapshots
      workspace_payloads.each do |workspace_payload|
        Array(workspace_payload["cupping_requests"]).each do |row|
          request = @cupping_request_map.fetch(old_id(row))
          request.update_columns(snapshot: remapped_cupping_snapshot(row.fetch("snapshot")))
        end
      end
    rescue KeyError
      invalid_cupping_request_data!
    end

    def remapped_cupping_snapshot(value)
      case value
      when Hash
        value.to_h do |key, nested|
          remapped = if key.end_with?("attachment_id") && nested.present?
            @attachment_map.fetch(nested).id
          else
            remapped_cupping_snapshot(nested)
          end
          [ key, remapped ]
        end
      when Array
        value.map { |nested| remapped_cupping_snapshot(nested) }
      else
        value
      end
    end

    def restore_primary_photo_ids(rows, record_map)
      rows.each do |row|
        next if row["primary_photo_attachment_id"].blank?

        record = record_map.fetch(old_id(row))
        attachment = @attachment_map[row.fetch("primary_photo_attachment_id")]
        record.update!(primary_photo_attachment_id: attachment.id) if attachment
      end
    end

    def restore_active_workspaces
      @active_workspace_targets.each do |user_id, old_workspace_id|
        next if old_workspace_id.blank?

        user = User.find(user_id)
        workspace = @workspace_map[old_workspace_id]
        user.update!(active_workspace: workspace) if workspace
      end
    end

    def restore_activity_events
      workspace_payloads.each do |workspace_payload|
        archived_workspace_id = old_id(workspace_payload.fetch("workspace"))
        workspace = @workspace_map.fetch(archived_workspace_id)
        Array(workspace_payload["activity_events"]).each do |row|
          restore_activity_event(row, workspace:, archived_workspace_id:)
        end
      end
      Array(payload["instance_activity_events"]).each do |row|
        restore_activity_event(row, workspace: nil, archived_workspace_id: nil)
      end
    end

    def restore_activity_event(row, workspace:, archived_workspace_id:)
      unless row.fetch("workspace_id") == archived_workspace_id
        raise RestoreError, "Archive activity workspace does not match its scope."
      end

      action = row.fetch("action")
      definition = Activity::EventContract.fetch(action)
      unless row.fetch("category") == definition.fetch(:category) &&
          definition.fetch(:visibilities).include?(row.fetch("visibility"))
        raise RestoreError, "Archive contains an invalid activity event."
      end
      archived_subject_type = row["subject_type"]
      archived_subject_id = row["subject_id"]
      unless archived_subject_type.present? == archived_subject_id.present?
        raise RestoreError, "Archive contains an invalid activity event."
      end
      if archived_subject_type.present? && archived_subject_type != definition.fetch(:subject_type)
        raise RestoreError, "Archive activity subject type does not match its action."
      end

      subject_map = ACTIVITY_SUBJECT_MAPS[archived_subject_type]
      subject = subject_map && instance_variable_get(subject_map)[archived_subject_id]
      actor = row["actor_id"].nil? ? nil : @user_map.fetch(row["actor_id"])
      subject = nil if historical_account_subject_out_of_scope?(action:, subject:, workspace:)
      validate_restored_activity_subject!(subject, workspace:)
      ActivityEvent.create!(
        workspace:,
        actor:,
        category: row.fetch("category"),
        action:,
        occurred_at: time(row.fetch("occurred_at")),
        visibility: row.fetch("visibility"),
        subject:,
        metadata: row.fetch("metadata").deep_dup,
        created_at: time(row.fetch("created_at")),
        updated_at: time(row.fetch("updated_at"))
      )
    rescue ActiveRecord::RecordInvalid, KeyError, ArgumentError
      raise RestoreError, "Archive contains an invalid activity event."
    end

    def historical_account_subject_out_of_scope?(action:, subject:, workspace:)
      Activity::EventContract::ACCOUNT_ACTIONS.include?(action) &&
        !Activity::SubjectScope.compatible?(subject:, workspace:)
    end

    def validate_restored_activity_subject!(subject, workspace:)
      return unless subject

      subject_workspace_id = if subject.is_a?(Workspace)
        subject.id
      elsif subject.respond_to?(:workspace_id)
        subject.workspace_id
      end
      if workspace && subject_workspace_id.present? && subject_workspace_id != workspace.id
        raise RestoreError, "Archive activity subject belongs to another workspace."
      end
      if workspace.nil? && subject_workspace_id.present? && !subject.is_a?(Workspace)
        raise RestoreError, "Archive instance activity subject cannot be workspace-scoped."
      end
    end

    def reset_exported_bean_inventory
      @bean_remaining_grams.each do |old_id, remaining_grams|
        @bean_map.fetch(old_id).update!(remaining_grams:)
      end
    end

    def summary
      {
        users: @user_map.size,
        workspaces: @workspace_map.size,
        beans: @bean_map.size,
        equipment: @equipment_map.size,
        preparation_tools: @preparation_tool_map.size,
        brews: @brew_map.size,
        cupping_requests: @cupping_request_map.size,
        external_coffees: @external_coffee_map.size,
        equipment_events: @equipment_event_map.size,
        inventory_adjustments: InventoryAdjustment.count,
        activity_events: ActivityEvent.count,
        media_files: @attachment_map.size
      }
    end

    def workspace_payloads
      payload.fetch("workspaces")
    end

    def restored_record_for(entry)
      record_map = {
        "User" => @user_map,
        "Workspace" => @workspace_map,
        "Bean" => @bean_map,
        "Equipment" => @equipment_map,
        "PreparationTool" => @preparation_tool_map,
        "Brew" => @brew_map,
        "ExternalCoffee" => @external_coffee_map,
        "EquipmentEvent" => @equipment_event_map
      }.fetch(entry.fetch("record_type"))
      record_map[entry.fetch("record_id")]
    end

    def restored_attachment(record, attachment_name)
      attachments_method = "#{attachment_name}_attachments"
      return record.public_send(attachments_method).order(:id).last if record.respond_to?(attachments_method)

      record.public_send("#{attachment_name}_attachment")
    end

    def optional_lookup(map, old_id)
      return if old_id.blank?

      map.fetch(old_id)
    end

    def schedule_restored_cupping_expirations
      @cupping_request_map.each_value do |request|
        next unless request.opened_at.present? && request.closed_at.blank? && request.feedback_expires_at&.future?

        CuppingRequestExpirationJob.schedule(
          request,
          dispatch_started_at: request.expiration_job_enqueueing_at
        )
      end
    end

    def invalid_cupping_request_data!
      raise RestoreError, "Archive contains an invalid cupping request."
    end

    def restore_brew_recipient!(brew, row, logger:)
      attributes = restored_brew_recipient_attributes(row, logger:)
      brew.update_columns(**attributes, updated_at: time(row.fetch("updated_at")))
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ActiveRecordError
      invalid_brew_recipient_data!
    end

    def restored_brew_recipient_attributes(row, logger:)
      kind = restored_recipient_kind(row)

      case kind
      when "self"
        { recipient_kind: "self", recipient_user_id: nil, recipient_name: nil }
      when "household_member"
        recipient = restored_recipient_user(row)
        invalid_brew_recipient_data! if recipient.id == logger.id

        { recipient_kind: "household_member", recipient_user_id: recipient.id, recipient_name: nil }
      when "guest"
        { recipient_kind: "guest", recipient_user_id: nil, recipient_name: restored_guest_name(row) }
      else
        invalid_brew_recipient_data!
      end
    end

    def restored_recipient_kind(row)
      value = row["recipient_kind"]
      if value.nil? || (value.is_a?(String) && value.strip.blank?)
        restored_legacy_recipient_kind(row)
      elsif value.is_a?(String) && value == value.strip
        value
      else
        invalid_brew_recipient_data!
      end
    end

    def restored_legacy_recipient_kind(row)
      return "self" unless row.key?("served_for_guest")

      case row["served_for_guest"]
      when true then "guest"
      when false, nil then "self"
      else invalid_brew_recipient_data!
      end
    end

    def restored_recipient_user(row)
      old_user_id = row["recipient_user_id"]
      invalid_brew_recipient_data! if old_user_id.blank?

      @user_map.fetch(old_user_id)
    rescue KeyError
      invalid_brew_recipient_data!
    end

    def restored_guest_name(row)
      value = row.key?("recipient_name") ? row["recipient_name"] : row["guest_name"]
      restored_optional_brew_string(value)
    end

    def restored_cup_style(row)
      restored_optional_brew_string(row["cup_style"])
    end

    def restored_optional_brew_string(value)
      return if value.nil?

      invalid_brew_recipient_data! unless value.is_a?(String)
      value = value.strip.presence
      invalid_brew_recipient_data! if value&.length.to_i > 120
      value
    end

    def invalid_brew_recipient_data!
      raise RestoreError, "Invalid brew recipient data"
    end

    def old_id(row)
      row.fetch("id")
    end

    def time(value)
      Time.iso8601(value) if value.present?
    end

    def date(value)
      Date.iso8601(value) if value.present?
    end
end
