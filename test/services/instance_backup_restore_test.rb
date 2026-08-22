require "test_helper"
require "zip"

class InstanceBackupRestoreTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "validator accepts a full archive with matching media checksums" do
    attachment = attach_photo(beans(:open_household))
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call

    result = InstanceBackupArchiveValidator.new(archive_bytes).call

    assert_predicate result, :valid?
    assert_empty result.errors
    assert_equal "roastnode.instance_backup_archive", result.manifest.fetch("format")
    assert result.manifest.fetch("files").any? { |file| file.fetch("attachment_id") == attachment.id }
  end

  test "validator rejects archives with corrupted media" do
    attachment = attach_photo(beans(:open_household))
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    media_path = nil

    tampered_archive = Zip::OutputStream.write_buffer do |output|
      Zip::File.open_buffer(archive_bytes) do |input|
        manifest = JSON.parse(input.read("manifest.json"))
        media_path = manifest.fetch("files").find { |file| file.fetch("attachment_id") == attachment.id }.fetch("path")

        input.each do |entry|
          output.put_next_entry(entry.name)
          output.write(entry.name == media_path ? "not the original file" : entry.get_input_stream.read)
        end
      end
    end.string

    result = InstanceBackupArchiveValidator.new(tampered_archive).call

    assert_not result.valid?
    assert_match(/checksum/i, result.errors.join(" "))
  end

  test "restorer refuses to import into a non-empty instance" do
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call

    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(archive_bytes).call
    end

    assert_match(/empty/i, error.message)
  end

  test "restorer rebuilds users workspaces coffee records and media into an empty instance with remapped ids" do
    users(:one).update!(
      display_name: "Restore Admin",
      instance_admin: true,
      active_workspace: workspaces(:household),
      enabled_brew_methods: [ "quick_drip" ],
      grams_per_coffee_spoon: 4.5
    )
    source_bean = beans(:open_household)
    source_bean_finished_at = Time.zone.parse("2026-05-24 18:30:00")
    source_bean.update!(
      remaining_grams: 14,
      finished_at: source_bean_finished_at,
      continent: "South America",
      country_of_manufacturer: "Germany",
      manufacturer: "Calendar Coffee"
    )
    quick_drip_bean = beans(:second_open_household)
    quick_drip_bean.update!(grind_state: "pre_ground")
    quick_drip_brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: quick_drip_bean,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )
    source_machine = equipment(:household_machine)
    source_machine.update!(
      preinfusion_enabled: true,
      low_flow_start_enabled: true,
      flow_control_enabled: true
    )
    espresso_brew = brews(:morning_espresso)
    espresso_brew.update!(low_flow_start_seconds: 9, flow_control_used: true)
    external_coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Americano",
      drink_size: "large",
      place_name: "Restore Cafe",
      place_location: "Cologne",
      latitude: 50.941278,
      longitude: 6.958281,
      price_cents: 390,
      currency: "EUR",
      acidity_balance: "bitter",
      intensity: "harsh",
      rating: 2,
      notes: "Private restore note",
      public_note: "Public restore note"
    )
    duplicated_bean = source_bean.duplicate_for_new_bag!
    duplicated_bean.update!(name: "Restored duplicate bag")
    attachment = attach_photo(beans(:open_household))
    external_photo = attach_photo(external_coffee)
    original = {
      users: User.count,
      workspaces: Workspace.count,
      beans: Bean.count,
      brews: Brew.count,
      external_coffees: ExternalCoffee.count,
      equipment: Equipment.count,
      inventory_adjustments: InventoryAdjustment.count,
      attachments: ActiveStorage::Attachment.count,
      user_id: users(:one).id,
      user_email: users(:one).email_address,
      workspace_id: workspaces(:household).id,
      workspace_name: workspaces(:household).name,
      password_digest: users(:one).password_digest,
      bean_name: source_bean.name,
      bean_finished_at: source_bean_finished_at,
      quick_drip_bean_name: quick_drip_bean.name,
      external_coffee_drink_type: external_coffee.drink_type,
      external_photo_filename: external_photo.blob.filename.to_s,
      brewer_name: equipment(:household_brewer).name,
      machine_name: source_machine.name,
      duplicated_bean_name: duplicated_bean.name,
      photo_filename: attachment.blob.filename.to_s
    }
    exported_activity_count = ActivityEvent.count
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call

    empty_instance!
    summary = InstanceBackupRestorer.new(archive_bytes).call

    restored_user = User.find_by!(email_address: original.fetch(:user_email))
    restored_workspace = Workspace.find_by!(name: original.fetch(:workspace_name))
    restored_bean = Bean.find_by!(name: original.fetch(:bean_name))
    restored_quick_drip_bean = Bean.find_by!(name: original.fetch(:quick_drip_bean_name))
    restored_duplicate_bean = Bean.find_by!(name: original.fetch(:duplicated_bean_name))
    restored_quick_drip_brew = restored_workspace.brews.find_by!(method: "quick_drip", bean: restored_quick_drip_bean)
    restored_machine = restored_workspace.equipment.find_by!(name: original.fetch(:machine_name))
    restored_espresso_brew = restored_workspace.brews.find_by!(method: "espresso", machine: restored_machine)
    restored_external_coffee = restored_workspace.external_coffees.find_by!(drink_type: original.fetch(:external_coffee_drink_type))
    restored_event = ActivityEvent.find_by!(
      workspace: restored_workspace,
      action: "brew.created",
      subject_type: "Brew",
      subject_id: restored_espresso_brew.id
    )

    assert_equal original.fetch(:users), User.count
    assert_equal original.fetch(:workspaces), Workspace.count
    assert_equal original.fetch(:beans), Bean.count
    assert_equal original.fetch(:brews), Brew.count
    assert_equal original.fetch(:external_coffees), ExternalCoffee.count
    assert_equal original.fetch(:equipment), Equipment.count
    assert_equal original.fetch(:inventory_adjustments), InventoryAdjustment.count
    assert_equal original.fetch(:attachments), ActiveStorage::Attachment.count
    assert_not_equal original.fetch(:user_id), restored_user.id
    assert_not_equal original.fetch(:workspace_id), restored_workspace.id
    assert_not_equal original.fetch(:password_digest), restored_user.password_digest
    assert_equal "Restore Admin", restored_user.display_name
    assert_predicate restored_user, :instance_admin?
    assert_equal [ "quick_drip" ], restored_user.enabled_brew_methods
    assert_equal 4.5.to_d, restored_user.grams_per_coffee_spoon
    assert_equal restored_workspace, restored_user.active_workspace
    assert_equal original.fetch(:bean_finished_at).to_i, restored_bean.finished_at.to_i
    assert_equal "finished", restored_bean.bag_status
    assert_equal "South America", restored_bean.continent
    assert_equal "Germany", restored_bean.country_of_manufacturer
    assert_equal "Calendar Coffee", restored_bean.manufacturer
    assert_equal "pre_ground", restored_quick_drip_bean.grind_state
    assert_equal "quick_drip", restored_quick_drip_brew.method
    assert_equal restored_quick_drip_bean, restored_quick_drip_brew.bean
    assert_equal original.fetch(:brewer_name), restored_quick_drip_brew.brewer.name
    assert_equal 6.to_d, restored_quick_drip_brew.machine_cups
    assert_equal 6.to_d, restored_quick_drip_brew.coffee_spoons
    assert_equal 4.5.to_d, restored_quick_drip_brew.grams_per_coffee_spoon
    assert_equal "estimated_spoons", restored_quick_drip_brew.coffee_amount_source
    assert_predicate restored_machine, :preinfusion_enabled?
    assert_predicate restored_machine, :low_flow_start_enabled?
    assert_predicate restored_machine, :flow_control_enabled?
    assert_equal 9, restored_espresso_brew.low_flow_start_seconds
    assert_predicate restored_espresso_brew, :flow_control_used?
    assert_equal "Restore Cafe", restored_external_coffee.place_name
    assert_equal "Cologne", restored_external_coffee.place_location
    assert_equal 390, restored_external_coffee.price_cents
    assert_equal "bitter", restored_external_coffee.acidity_balance
    assert_equal "harsh", restored_external_coffee.intensity
    assert_equal original.fetch(:external_photo_filename), restored_external_coffee.photos.first.filename.to_s
    assert_equal original.fetch(:photo_filename), restored_bean.photos.first.filename.to_s
    assert_equal restored_bean, restored_duplicate_bean.duplicated_from_bean
    assert_equal "Jens", restored_event.metadata.fetch("actor_label")
    assert_equal restored_event.workspace, restored_event.subject.workspace
    assert ActivityEvent.exists?(workspace_id: nil, action: "instance_backup_run.succeeded")
    assert_equal exported_activity_count, ActivityEvent.count
    assert_equal(
      {
        users: original.fetch(:users),
        workspaces: original.fetch(:workspaces),
        beans: original.fetch(:beans),
        brews: original.fetch(:brews),
        external_coffees: original.fetch(:external_coffees),
        media_files: original.fetch(:attachments)
      },
      summary.slice(:users, :workspaces, :beans, :brews, :external_coffees, :media_files)
    )
  end

  test "restorer drops invalid bean purchase urls instead of failing restore" do
    source_bean_name = beans(:open_household).name
    archive_bytes = mutate_backup_payload(
      InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    ) do |payload|
      household = payload.fetch("workspaces").find { |workspace_payload| workspace_payload.dig("workspace", "name") == workspaces(:household).name }
      household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }["purchase_url"] = "javascript:alert('bean')"
    end

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_bean = Bean.find_by!(name: source_bean_name)
    assert_nil restored_bean.purchase_url
  end

  test "restorer rejects a target containing only a backup profile" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    empty_instance!
    InstanceBackupProfile.create!(
      name: "Residual profile", backup_kind: "full_archive", enabled: false, schedule: "manual",
      storage_path: "storage/instance_backups", retention_count: 7
    )

    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(archive_bytes).call
    end

    assert_equal "Target instance must be empty before restore.", error.message
    assert_equal 0, User.count
    assert_equal 0, Workspace.count
    assert_equal 1, InstanceBackupProfile.count
  end

  test "restorer rejects activity metadata keys not permitted for the archived action" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
      event.fetch("metadata")["backup_kind"] = "full_archive"
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects leading paths and overlong strings inside metadata arrays" do
    source_event = Activity::Emitter.record!(
      action: "equipment_event.created", workspace: workspaces(:household), actor: users(:one),
      subject: equipment_events(:grinder_cleaning), occurred_at: equipment_events(:grinder_cleaning).occurred_at
    )
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("id") == source_event.id }
      event.fetch("metadata")["event_types"] = [ "../private/event", "x" * 161 ]
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects category and visibility that do not match the archived action" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archives = [
      [ "category", "system_security" ],
      [ "visibility", "workspace_admin" ]
    ].map do |key, value|
      mutate_backup_payload(archive_bytes) do |payload|
        household = payload.fetch("workspaces").find do |workspace_payload|
          workspace_payload.dig("workspace", "name") == workspaces(:household).name
        end
        event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
        event[key] = value
      end
    end

    tampered_archives.each do |tampered_archive|
      empty_instance!
      error = assert_raises(InstanceBackupRestorer::RestoreError) do
        InstanceBackupRestorer.new(tampered_archive).call
      end
      assert_equal "Archive contains an invalid activity event.", error.message
      assert_equal 0, ActivityEvent.count
      assert_equal 0, Workspace.count
    end
  end

  test "restorer rejects an activity subject type that does not match its action" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
      event["subject_type"] = "Bean"
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive activity subject type does not match its action.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects a remapped activity subject from another workspace" do
    household_event_id = activity_events(:morning_brew_created).id
    foreign_brew_id = brews(:other_workspace_brew).id
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("id") == household_event_id }
      event["subject_id"] = foreign_brew_id
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive activity subject belongs to another workspace.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects activity workspace ids that conflict with archive scope" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archives = [
      mutate_backup_payload(archive_bytes) do |payload|
        household = payload.fetch("workspaces").find do |workspace_payload|
          workspace_payload.dig("workspace", "name") == workspaces(:household).name
        end
        event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
        event["workspace_id"] = workspaces(:other_household).id
      end,
      mutate_backup_payload(archive_bytes) do |payload|
        event = payload.fetch("instance_activity_events").first
        event["workspace_id"] = workspaces(:household).id
      end
    ]

    tampered_archives.each do |tampered_archive|
      empty_instance!
      error = assert_raises(InstanceBackupRestorer::RestoreError) do
        InstanceBackupRestorer.new(tampered_archive).call
      end
      assert_equal "Archive activity workspace does not match its scope.", error.message
      assert_equal 0, ActivityEvent.count
      assert_equal 0, Workspace.count
    end
  end

  test "restorer accepts version one archives without activity events" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    older_archive = mutate_backup_payload(archive_bytes) do |payload|
      payload.delete("instance_activity_events")
      payload.fetch("workspaces").each { |workspace_payload| workspace_payload.delete("activity_events") }
    end

    empty_instance!
    summary = InstanceBackupRestorer.new(older_archive).call

    assert_equal 0, ActivityEvent.count
    assert_equal 0, summary.fetch(:activity_events)
    assert Workspace.exists?
  end

  test "restorer degrades valid activity with an unexported subject to a tombstone" do
    source_event = Activity::Emitter.record!(
      action: "recipe.created", workspace: workspaces(:household), actor: users(:one),
      subject: recipes(:household_recipe), occurred_at: Time.zone.parse("2026-08-20 11:12:13")
    )
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_event = ActivityEvent.find_by!(action: "recipe.created")
    assert_nil restored_event.subject
    assert_equal source_event.metadata, restored_event.metadata
    assert_equal source_event.occurred_at, restored_event.occurred_at
  end

  private
    def mutate_backup_payload(archive_bytes)
      Zip::OutputStream.write_buffer do |output|
        Zip::File.open_buffer(archive_bytes) do |input|
          manifest = JSON.parse(input.read("manifest.json"))
          data_path = manifest.dig("data", "path")
          payload = JSON.parse(input.read(data_path))
          yield payload

          input.each do |entry|
            output.put_next_entry(entry.name)
            if entry.name == data_path
              output.write(JSON.pretty_generate(payload))
            else
              output.write(entry.get_input_stream.read)
            end
          end
        end
      end.string
    end

    def empty_instance!
      ActivityEvent.delete_all
      InstanceBackupRun.delete_all
      InstanceBackupProfile.delete_all
      ActiveStorage::VariantRecord.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Session.delete_all
      WorkspaceInvite.delete_all
      HouseholdInvite.delete_all
      InventoryAdjustment.delete_all
      BrewPreparationTool.delete_all
      EquipmentEventItem.delete_all
      EquipmentEvent.delete_all
      PublicRecipeShare.delete_all
      Recipe.delete_all
      Brew.delete_all
      ExternalCoffee.delete_all
      PreparationTool.delete_all
      Equipment.delete_all
      Bean.delete_all
      DataImport.delete_all
      Membership.delete_all
      PasskeyCredential.delete_all
      User.update_all(active_workspace_id: nil)
      Workspace.delete_all
      User.delete_all
    end
end
