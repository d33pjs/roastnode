require "test_helper"
require "zip"

class InstanceBackupRestoreTest < ActiveSupport::TestCase
  include PhotoTestHelper

  setup do
    cupping_requests(:guest_espresso).brew.update!(recipient_kind: "guest", recipient_name: "Fixture Guest")
    cupping_requests(:guest_espresso).refresh_snapshot!
  end

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

  test "restorer round trips cupping requests and schedules only open future feedback" do
    now = Time.zone.parse("2026-08-29 12:00:00")
    future_request = build_backup_cupping_request(
      notes: "future cupping restore",
      opened_at: now - 2.hours,
      feedback_expires_at: now + 22.hours,
      expiration_job_enqueued_at: now - 119.minutes,
      expiration_job_enqueueing_at: now - 118.minutes,
      feedback_comment: "Private restore feedback",
      last_guest_ip: "2001:db8::44"
    )
    unopened_request = cupping_requests(:guest_espresso)
    unopened_request.brew.update!(recipient_kind: "guest", recipient_name: "Unopened Guest")
    closed_request = build_backup_cupping_request(
      notes: "closed cupping restore",
      opened_at: now - 2.days,
      feedback_expires_at: now - 1.day,
      closed_at: now - 1.day,
      last_guest_ip: "203.0.113.8"
    )
    expired_request = build_backup_cupping_request(
      notes: "expired cupping restore",
      opened_at: now - 25.hours,
      feedback_expires_at: now - 1.hour,
      last_guest_ip: "203.0.113.9"
    )
    original = future_request.attributes.slice(
      "token", "token_digest", "snapshot", "feedback_comment", "opened_at", "feedback_expires_at", "closed_at",
      "last_guest_ip", "created_at", "updated_at"
    )
    original_request_count = CuppingRequest.count
    archive_bytes = travel_to(now) { InstanceBackupArchiveBuilder.new(generated_at: now).call }
    scheduled = []

    empty_instance!
    travel_to now do
      with_stubbed_singleton_method(
        CuppingRequestExpirationJob,
        :schedule,
        lambda do |request, dispatch_started_at:|
          scheduled << [ request, dispatch_started_at ]
          true
        end
      ) do
        InstanceBackupRestorer.new(archive_bytes).call
      end
    end

    restored = CuppingRequest.find_by_token!(original.fetch("token"))
    assert_equal original_request_count, CuppingRequest.count
    assert_not_equal future_request.id, restored.id
    assert_equal restored.workspace, restored.brew.workspace
    assert_predicate restored.brew, :espresso?
    assert_predicate restored.brew, :recipient_guest?
    assert_equal original, restored.attributes.slice(*original.keys)
    assert_equal 1, scheduled.size
    assert_equal restored, scheduled.first.first
    assert_nil scheduled.first.last
    assert_nil restored.expiration_job_enqueued_at
    assert_nil restored.expiration_job_enqueueing_at
    assert_not_includes scheduled.map { |entry| entry.first.token }, unopened_request.token
    assert_not_includes scheduled.map { |entry| entry.first.token }, closed_request.token
    assert_not_includes scheduled.map { |entry| entry.first.token }, expired_request.token
  end

  test "restorer clears archived expiration dispatch state when immediate scheduling returns false" do
    now = Time.zone.parse("2026-08-29 12:00:00")
    request = build_backup_cupping_request(
      notes: "failed restored schedule",
      opened_at: now - 2.hours,
      feedback_expires_at: now + 22.hours,
      expiration_job_enqueued_at: now - 119.minutes,
      expiration_job_enqueueing_at: now - 118.minutes,
      last_guest_ip: "203.0.113.20"
    )
    archive_bytes = travel_to(now) { InstanceBackupArchiveBuilder.new(generated_at: now).call }
    schedule_calls = []

    empty_instance!
    travel_to now do
      with_stubbed_singleton_method(
        CuppingRequestExpirationJob,
        :schedule,
        lambda do |restored_request, dispatch_started_at:|
          schedule_calls << [ restored_request, dispatch_started_at ]
          false
        end
      ) do
        InstanceBackupRestorer.new(archive_bytes).call
      end
    end

    restored = CuppingRequest.find_by_token!(request.token)
    assert_equal [ [ restored, nil ] ], schedule_calls
    assert_nil restored.expiration_job_enqueued_at
    assert_nil restored.expiration_job_enqueueing_at
    assert_predicate restored, :expiration_dispatch_pending?
  end

  test "restorer keeps a committed restore successful when expiration scheduling raises" do
    now = Time.zone.parse("2026-08-29 12:00:00")
    first = build_backup_cupping_request(
      notes: "first failed restored schedule",
      opened_at: now - 2.hours,
      feedback_expires_at: now + 22.hours,
      last_guest_ip: "203.0.113.21"
    )
    second = build_backup_cupping_request(
      notes: "second failed restored schedule",
      opened_at: now - 1.hour,
      feedback_expires_at: now + 23.hours,
      last_guest_ip: "203.0.113.22"
    )
    archive_bytes = travel_to(now) { InstanceBackupArchiveBuilder.new(generated_at: now).call }
    schedule_calls = []

    empty_instance!
    summary = travel_to(now) do
      with_stubbed_singleton_method(
        CuppingRequestExpirationJob,
        :schedule,
        lambda do |restored_request, dispatch_started_at:|
          schedule_calls << [ restored_request, dispatch_started_at ]
          raise SolidQueue::Job::EnqueueError, "queue unavailable"
        end
      ) do
        InstanceBackupRestorer.new(archive_bytes).call
      end
    end

    restored = [ first, second ].map { |request| CuppingRequest.find_by_token!(request.token) }
    assert_equal CuppingRequest.count, summary.fetch(:cupping_requests)
    assert_equal restored.sort, schedule_calls.map(&:first).sort
    assert schedule_calls.all? { |entry| entry.last.nil? }
    restored.each do |request|
      assert_nil request.expiration_job_enqueued_at
      assert_nil request.expiration_job_enqueueing_at
      assert_predicate request, :expiration_dispatch_pending?
    end
  end

  test "validator and restorer reject hostile cupping request state with full rollback" do
    request = build_backup_cupping_request(
      notes: "hostile cupping source",
      opened_at: Time.zone.parse("2026-08-28 10:00:00"),
      feedback_expires_at: Time.zone.parse("2026-08-29 10:00:00"),
      feedback_comment: "Safe private feedback",
      last_guest_ip: "203.0.113.44"
    )
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-28 12:00:00")).call
    other_workspace_id = workspaces(:other_household).id
    other_brew_id = brews(:other_workspace_brew).id
    mutations = {
      mismatched_workspace: ->(row) { row["workspace_id"] = other_workspace_id },
      foreign_brew: ->(row) { row["brew_id"] = other_brew_id },
      token_digest_mismatch: ->(row) { row["token_digest"] = Digest::SHA256.hexdigest("different-token") },
      overlong_comment: ->(row) { row["feedback_comment"] = "x" * 2_001 },
      invalid_deadline: ->(row) { row["feedback_expires_at"] = row.fetch("opened_at") },
      missing_opened_ip: ->(row) { row["last_guest_ip"] = nil },
      nil_snapshot: ->(row) { row["snapshot"] = nil },
      scalar_snapshot: ->(row) { row["snapshot"] = "public-looking scalar" },
      array_snapshot: ->(row) { row["snapshot"] = [] },
      missing_snapshot_structure: ->(row) { row.fetch("snapshot").delete("title") },
      extra_private_snapshot_field: ->(row) { row.fetch("snapshot").fetch("brew")["notes"] = "nested-secret" },
      malformed_attachment_reference: lambda do |row|
        row.fetch("snapshot").fetch("public_media") << { "attachment_id" => { "id" => 123 } }
      end
    }

    mutations.each do |case_name, mutation|
      tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
        row = cupping_request_row(payload, request)
        mutation.call(row)
      end
      validation = InstanceBackupArchiveValidator.new(tampered_archive).call
      assert_not_predicate validation, :valid?, case_name.to_s

      empty_instance!
      error = assert_raises(InstanceBackupRestorer::RestoreError, case_name.to_s) do
        InstanceBackupRestorer.new(tampered_archive).call
      end

      assert_match(/cupping request/i, error.message, case_name.to_s)
      assert_no_match(/nested-secret|Safe private feedback/, error.message, case_name.to_s)
      assert_equal 0, CuppingRequest.count, case_name.to_s
      assert_equal 0, Workspace.count, case_name.to_s
    end
  end

  test "validator rejects payload media ownership that differs from the manifest before cupping restore" do
    workspace = workspaces(:household)
    logo = attach_named_photo(workspace, :logo, filename: "household-logo.jpg")
    private_photo = attach_photo(beans(:open_household))
    request = build_backup_cupping_request(
      notes: "media catalog substitution",
      opened_at: nil,
      feedback_expires_at: nil
    )
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-28 12:00:00")).call

    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      logo_file = payload.fetch("media_files").find { |file| file.fetch("attachment_id") == logo.id }
      private_file = payload.fetch("media_files").find { |file| file.fetch("attachment_id") == private_photo.id }
      ownership_keys = %w[record_type record_id attachment_name]
      logo_ownership = logo_file.slice(*ownership_keys)
      private_ownership = private_file.slice(*ownership_keys)
      logo_file.merge!(private_ownership)
      private_file.merge!(logo_ownership)

      snapshot = cupping_request_row(payload, request).fetch("snapshot")
      snapshot.fetch("workspace")["logo_attachment_id"] = private_photo.id
      snapshot.fetch("public_media").find { |media| media.fetch("attachment_id") == logo.id }["attachment_id"] = private_photo.id
    end

    validation = InstanceBackupArchiveValidator.new(tampered_archive).call
    assert_not_predicate validation, :valid?
    assert_match(/media catalog/i, validation.errors.join(" "))

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end
    assert_match(/media catalog/i, error.message)
    assert_equal 0, Workspace.count
    assert_equal 0, ActiveStorage::Attachment.count
  end

  test "validator accepts a stale cupping identity snapshot after logo and avatar replacement" do
    request = cupping_requests(:guest_espresso)
    workspace = request.workspace
    user = request.brew.user
    original_logo = attach_named_photo(workspace, :logo, filename: "original-logo.jpg")
    original_avatar = attach_named_photo(user, :avatar, filename: "original-avatar.jpg")
    request.refresh_snapshot!

    attach_named_photo(workspace, :logo, filename: "replacement-logo.jpg")
    attach_named_photo(user, :avatar, filename: "replacement-avatar.jpg")
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-29 12:00:00")).call

    result = InstanceBackupArchiveValidator.new(archive_bytes).call

    assert_predicate result, :valid?
    archived_snapshot = cupping_request_row(result.payload, request).fetch("snapshot")
    assert_nil archived_snapshot.fetch("workspace").fetch("logo_attachment_id")
    assert_nil archived_snapshot.fetch("user").fetch("avatar_attachment_id")
    assert_equal [], archived_snapshot.fetch("public_media")
    assert_not_equal workspace.logo.attachment.id, original_logo.id
    assert_not_equal user.avatar.attachment.id, original_avatar.id
  end

  test "validator rejects a foreign cupping snapshot identity reference" do
    request = cupping_requests(:guest_espresso)
    workspace = request.workspace
    user = request.brew.user
    attach_named_photo(workspace, :logo, filename: "household-logo.jpg")
    attach_named_photo(user, :avatar, filename: "logger-avatar.jpg")
    request.refresh_snapshot!
    foreign_attachment = attach_photo(beans(:open_household))
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-29 12:00:00")).call

    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      snapshot = cupping_request_row(payload, request).fetch("snapshot")
      snapshot.fetch("workspace")["logo_attachment_id"] = foreign_attachment.id
      snapshot["public_media"] = [ { "attachment_id" => foreign_attachment.id } ]
    end

    validation = InstanceBackupArchiveValidator.new(tampered_archive).call

    assert_not_predicate validation, :valid?
    assert_match(/cupping request/i, validation.errors.join(" "))
  end

  test "validator accepts a 120-character multibyte public link label" do
    request = cupping_requests(:guest_espresso)
    request.brew.record_links.create!(
      workspace: request.workspace,
      label: "ä" * 120,
      url: "https://example.com/coffee",
      kind: "info",
      visibility: "public",
      position: 10
    )
    request.refresh_snapshot!
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-29 12:00:00")).call

    result = InstanceBackupArchiveValidator.new(archive_bytes).call

    assert_predicate result, :valid?
  end

  test "validator rejects a 121-character multibyte public link label" do
    request = cupping_requests(:guest_espresso)
    request.brew.record_links.create!(
      workspace: request.workspace,
      label: "ä" * 120,
      url: "https://example.com/coffee",
      kind: "info",
      visibility: "public",
      position: 10
    )
    request.refresh_snapshot!
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-29 12:00:00")).call

    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      link = cupping_request_row(payload, request).fetch("snapshot").fetch("brew").fetch("links").first
      link["label"] = "ä" * 121
    end

    validation = InstanceBackupArchiveValidator.new(tampered_archive).call

    assert_not_predicate validation, :valid?
    assert_match(/cupping request/i, validation.errors.join(" "))
  end

  test "restorer rebuilds users workspaces coffee records and media into an empty instance with remapped ids" do
    users(:one).update!(
      display_name: "Restore Admin",
      instance_admin: true,
      active_workspace: workspaces(:household),
      enabled_brew_methods: [ "quick_drip" ],
      grams_per_coffee_spoon: 4.5
    )
    current_recipient = users(:two)
    current_recipient.update!(display_name: "Current Restore Recipient")
    former_recipient = User.create!(
      email_address: "former-restore-recipient@example.com",
      password: "password",
      display_name: "Former Restore Recipient"
    )
    former_membership = workspaces(:household).memberships.create!(user: former_recipient, role: "member")
    source_bean = beans(:open_household)
    source_bean_finished_at = Time.zone.parse("2026-05-24 18:30:00")
    source_bean.update!(
      remaining_grams: 14,
      finished_at: source_bean_finished_at,
      continent: "South America",
      country_of_manufacturer: "Germany",
      manufacturer: "Calendar Coffee",
      purchase_url: "https://shop.example/house-blend",
      coffee_origin_url: "https://origin.example/house-blend"
    )
    quick_drip_bean = beans(:second_open_household)
    quick_drip_bean.update!(grind_state: "pre_ground")
    quick_drip_brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: quick_drip_bean,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      recipient_kind: "self",
      cup_style: "Batch Carafe",
      notes: "restore quick drip self"
    )
    source_machine = equipment(:household_machine)
    source_machine.update!(
      preinfusion_enabled: true,
      low_flow_start_enabled: true,
      flow_control_enabled: true
    )
    espresso_brew = brews(:morning_espresso)
    espresso_brew.update!(
      low_flow_start_seconds: 9,
      flow_control_used: true,
      recipient_kind: "self",
      cup_style: "Demitasse",
      notes: "restore espresso self"
    )
    household_brew = create_restore_recipient_brew(
      recipient_kind: "household_member",
      recipient_user: current_recipient,
      cup_style: "Household Mug",
      notes: "restore current household"
    )
    named_guest_brew = create_restore_recipient_brew(
      recipient_kind: "guest",
      recipient_name: "Private Restore Anna",
      cup_style: "Guest Latte",
      notes: "restore named guest"
    )
    unnamed_guest_brew = create_restore_recipient_brew(
      recipient_kind: "guest",
      recipient_name: nil,
      cup_style: "Guest Cup",
      notes: "restore unnamed guest"
    )
    former_brew = create_restore_recipient_brew(
      recipient_kind: "household_member",
      recipient_user: former_recipient,
      cup_style: "Former Cortado",
      notes: "restore former household"
    )
    former_membership.destroy!
    archived_household_updated_at = Time.zone.parse("2026-05-23 14:15:16")
    household_brew.update_columns(updated_at: archived_household_updated_at)
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
      blobs: ActiveStorage::Blob.count,
      user_id: users(:one).id,
      user_email: users(:one).email_address,
      current_recipient_id: current_recipient.id,
      current_recipient_email: current_recipient.email_address,
      former_recipient_id: former_recipient.id,
      former_recipient_email: former_recipient.email_address,
      household_updated_at: archived_household_updated_at,
      workspace_id: workspaces(:household).id,
      workspace_name: workspaces(:household).name,
      password_digest: users(:one).password_digest,
      bean_name: source_bean.name,
      bean_finished_at: source_bean_finished_at,
      bean_purchase_url: source_bean.purchase_url,
      bean_coffee_origin_url: source_bean.coffee_origin_url,
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
    restored_household_brew = restored_workspace.brews.find_by!(notes: "restore current household")
    restored_named_guest_brew = restored_workspace.brews.find_by!(notes: "restore named guest")
    restored_unnamed_guest_brew = restored_workspace.brews.find_by!(notes: "restore unnamed guest")
    restored_former_brew = restored_workspace.brews.find_by!(notes: "restore former household")
    restored_current_recipient = User.find_by!(email_address: original.fetch(:current_recipient_email))
    restored_former_recipient = User.find_by!(email_address: original.fetch(:former_recipient_email))
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
    assert_equal original.fetch(:blobs), ActiveStorage::Blob.count
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
    assert_equal original.fetch(:bean_purchase_url), restored_bean.purchase_url
    assert_equal original.fetch(:bean_coffee_origin_url), restored_bean.coffee_origin_url
    assert_equal "pre_ground", restored_quick_drip_bean.grind_state
    assert_equal "quick_drip", restored_quick_drip_brew.method
    assert_equal restored_quick_drip_bean, restored_quick_drip_brew.bean
    assert_equal original.fetch(:brewer_name), restored_quick_drip_brew.brewer.name
    assert_equal 6.to_d, restored_quick_drip_brew.machine_cups
    assert_equal 6.to_d, restored_quick_drip_brew.coffee_spoons
    assert_equal 4.5.to_d, restored_quick_drip_brew.grams_per_coffee_spoon
    assert_equal "estimated_spoons", restored_quick_drip_brew.coffee_amount_source
    assert_predicate restored_quick_drip_brew, :recipient_self?
    assert_equal "Batch Carafe", restored_quick_drip_brew.cup_style
    assert_predicate restored_espresso_brew, :recipient_self?
    assert_equal "Demitasse", restored_espresso_brew.cup_style
    assert_predicate restored_household_brew, :recipient_household_member?
    assert_equal restored_current_recipient, restored_household_brew.recipient_user
    assert_not_equal restored_household_brew.user, restored_household_brew.recipient_user
    assert_not_equal original.fetch(:current_recipient_id), restored_current_recipient.id
    assert_nil restored_household_brew.recipient_name
    assert_equal "Household Mug", restored_household_brew.cup_style
    assert_equal original.fetch(:household_updated_at), restored_household_brew.updated_at
    assert_predicate restored_named_guest_brew, :recipient_guest?
    assert_nil restored_named_guest_brew.recipient_user
    assert_equal "Private Restore Anna", restored_named_guest_brew.recipient_name
    assert_equal "Guest Latte", restored_named_guest_brew.cup_style
    assert_predicate restored_unnamed_guest_brew, :recipient_guest?
    assert_nil restored_unnamed_guest_brew.recipient_user
    assert_nil restored_unnamed_guest_brew.recipient_name
    assert_equal "Guest Cup", restored_unnamed_guest_brew.cup_style
    assert_predicate restored_former_brew, :recipient_household_member?
    assert_equal restored_former_recipient, restored_former_brew.recipient_user
    assert_not_equal original.fetch(:former_recipient_id), restored_former_recipient.id
    assert_nil restored_former_recipient.membership_for(restored_workspace)
    assert_equal "Former Cortado", restored_former_brew.cup_style
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
    assert_equal restored_user, restored_event.actor
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

  test "restorer drops an unsafe bean purchase url while preserving a safe origin url" do
    source_bean_name = beans(:open_household).name
    archive_bytes = mutate_backup_payload(
      InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    ) do |payload|
      household = payload.fetch("workspaces").find { |workspace_payload| workspace_payload.dig("workspace", "name") == workspaces(:household).name }
      row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
      row["purchase_url"] = "javascript:alert('purchase')"
      row["coffee_origin_url"] = "https://origin.example/safe-coffee"
    end

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_bean = Bean.find_by!(name: source_bean_name)
    assert_nil restored_bean.purchase_url
    assert_equal "https://origin.example/safe-coffee", restored_bean.coffee_origin_url
  end

  test "restorer preserves a safe bean purchase url while dropping an unsafe origin url" do
    source_bean_name = beans(:open_household).name
    archive_bytes = mutate_backup_payload(
      InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    ) do |payload|
      household = payload.fetch("workspaces").find { |workspace_payload| workspace_payload.dig("workspace", "name") == workspaces(:household).name }
      row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
      row["purchase_url"] = "https://shop.example/safe-coffee"
      row["coffee_origin_url"] = "data:text/html,unsafe-origin"
    end

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_bean = Bean.find_by!(name: source_bean_name)
    assert_equal "https://shop.example/safe-coffee", restored_bean.purchase_url
    assert_nil restored_bean.coffee_origin_url
  end

  test "restorer normalizes a numeric legacy bean rating zero when origin url is absent" do
    source_bean_name = beans(:open_household).name
    archive_bytes = mutate_backup_payload(
      InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    ) do |payload|
      household = payload.fetch("workspaces").find { |workspace_payload| workspace_payload.dig("workspace", "name") == workspaces(:household).name }
      row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
      row["purchase_url"] = "https://shop.example/legacy-coffee"
      row["rating"] = 0
      row.delete("coffee_origin_url")
    end

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_bean = Bean.find_by!(name: source_bean_name)
    assert_nil restored_bean.rating
    assert_equal "https://shop.example/legacy-coffee", restored_bean.purchase_url
    assert_nil restored_bean.coffee_origin_url
  end

  test "restorer normalizes a string legacy bean rating zero when origin url is absent" do
    source_bean_name = beans(:open_household).name
    archive_bytes = mutate_backup_payload(
      InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
    ) do |payload|
      household = payload.fetch("workspaces").find { |workspace_payload| workspace_payload.dig("workspace", "name") == workspaces(:household).name }
      row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
      row["rating"] = "0"
      row.delete("coffee_origin_url")
    end

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_bean = Bean.find_by!(name: source_bean_name)
    assert_nil restored_bean.rating
    assert_nil restored_bean.coffee_origin_url
  end

  test "malformed nonzero bean rating raises sanitized restore error with full rollback" do
    attachment = attach_photo(beans(:open_household))
    source_workspace_id = workspaces(:household).id
    source_bean_id = beans(:open_household).id
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-05-28 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "id") == source_workspace_id
      end
      row = household.fetch("beans").find { |bean| bean.fetch("id") == source_bean_id }
      row["rating"] = "6 Private restore rating"
    end

    empty_instance!
    starting_counts = restore_boundary_counts

    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Invalid bean data", error.message
    assert_no_match(/Private|#{attachment.id}|#{attachment.blob_id}/, error.message)
    assert_equal starting_counts, restore_boundary_counts
    assert_equal 0, Bean.count
    assert_equal 0, ActivityEvent.count
    assert_equal 0, ActiveStorage::Attachment.count
    assert_equal 0, ActiveStorage::Blob.count
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

  test "restorer rejects blank and control-character activity actor labels" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archives = [ "", "   ", "Jens\0" ].map do |actor_label|
      mutate_backup_payload(archive_bytes) do |payload|
        household = payload.fetch("workspaces").find do |workspace_payload|
          workspace_payload.dig("workspace", "name") == workspaces(:household).name
        end
        event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
        event.fetch("metadata")["actor_label"] = actor_label
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

  test "restorer rejects leading paths inside metadata arrays" do
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
      event.fetch("metadata")["equipment_labels"] = [ "../private/event" ]
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects overlong strings inside metadata arrays" do
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
      event.fetch("metadata")["equipment_labels"] = [ "x" * 161 ]
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

  test "restorer rejects an unknown activity action" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
      event["action"] = "brew.hostile"
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects invalid guest cupping actor metadata IP addresses and missing Brew subjects" do
    brew = brews(:morning_espresso)
    source_event = Activity::Emitter.record!(
      action: "brew.cupping_accessed", workspace: brew.workspace, subject: brew,
      actor_kind: "guest", actor_label: "Alex", details: { ip_address: "203.0.113.4" }
    )
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call

    tampered_archives = [
      lambda do |row|
        row["action"] = "brew.created"
        row.fetch("metadata").delete("ip_address")
      end,
      lambda { |row| row["actor_id"] = users(:one).id },
      lambda do |row|
        row["actor_id"] = users(:one).id
        row.fetch("metadata")["actor_kind"] = "user"
        row.fetch("metadata")["actor_label"] = "Jens"
      end,
      lambda do |row|
        row["actor_id"] = nil
        row.fetch("metadata")["actor_kind"] = "system"
        row.fetch("metadata")["actor_label"] = "System"
      end,
      lambda { |row| row.fetch("metadata")["ip_address"] = "203.0.113.4, 10.0.0.1" },
      lambda do |row|
        row["subject_type"] = nil
        row["subject_id"] = nil
      end
    ].map do |tamper|
      mutate_backup_payload(archive_bytes) do |payload|
        household = payload.fetch("workspaces").find do |workspace_payload|
          workspace_payload.dig("workspace", "name") == brew.workspace.name
        end
        event = household.fetch("activity_events").find { |row| row.fetch("id") == source_event.id }
        tamper.call(event)
      end
    end

    tampered_archives.each do |tampered_archive|
      empty_instance!

      error = assert_raises(InstanceBackupRestorer::RestoreError) do
        InstanceBackupRestorer.new(tampered_archive).call
      end

      assert_equal "Archive contains an invalid activity event.", error.message
      assert_equal 0, ActivityEvent.count
    end
  end

  test "restorer rejects a partial activity subject pair" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archives = [
      [ "subject_type", nil ],
      [ "subject_id", nil ]
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

  test "restorer rejects a workspace-owned subject inside instance activity" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      event = payload.fetch("instance_activity_events").first
      source = activity_events(:morning_brew_created)
      event.merge!(
        "category" => "coffee",
        "action" => "brew.created",
        "visibility" => "workspace",
        "subject_type" => "Brew",
        "subject_id" => brews(:morning_espresso).id,
        "metadata" => source.metadata.deep_dup
      )
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive instance activity subject cannot be workspace-scoped.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer rejects a non-null activity actor that cannot be remapped" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
      event["actor_id"] = User.maximum(:id) + 1_000
    end

    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end

    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end

  test "restorer accepts version one archives without activity events" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    older_archive = mutate_backup_payload(archive_bytes) do |payload|
      payload.delete("instance_activity_events")
      payload.fetch("workspaces").each do |workspace_payload|
        workspace_payload.delete("activity_events")
        workspace_payload.delete("cupping_requests")
      end
    end

    empty_instance!
    summary = InstanceBackupRestorer.new(older_archive).call

    assert_equal 0, ActivityEvent.count
    assert_equal 0, summary.fetch(:activity_events)
    eligible_brews = Brew.where(method: "espresso", recipient_kind: "guest")
    ineligible_brews = Brew.where.not(id: eligible_brews.select(:id))
    assert_operator eligible_brews.count, :>, 0
    assert_equal eligible_brews.count, CuppingRequest.count
    assert_equal eligible_brews.count, summary.fetch(:cupping_requests)
    assert eligible_brews.all? { |brew| brew.cupping_request.present? }
    assert ineligible_brews.all? { |brew| brew.cupping_request.nil? }
    assert Workspace.exists?
  end

  test "restorer reconciles eligible brews when a version one cupping collection is null" do
    brew = create_restore_recipient_brew(
      recipient_kind: "guest", recipient_name: "Null Collection Guest", cup_style: "Tasting Cup",
      notes: "null cupping collection"
    )
    removed_request = CuppingRequests::Synchronize.call(brew)
    preserved_request = cupping_requests(:guest_espresso)
    preserved_token = preserved_request.token
    archive_bytes = InstanceBackupArchiveBuilder.new.call
    archive_with_null = mutate_backup_payload(archive_bytes) do |payload|
      workspace_payload = payload.fetch("workspaces").find do |item|
        item.dig("workspace", "id") == brew.workspace_id
      end
      workspace_payload["cupping_requests"] = nil
    end

    empty_instance!
    summary = InstanceBackupRestorer.new(archive_with_null).call

    restored_brew = Brew.find_by!(notes: "null cupping collection")
    restored_request = restored_brew.cupping_request
    assert restored_request
    assert_not_equal removed_request.token, restored_request.token
    assert CuppingRequest.find_by_token!(preserved_token)
    assert_equal Brew.where(method: "espresso", recipient_kind: "guest").count, CuppingRequest.count
    assert_equal CuppingRequest.count, summary.fetch(:cupping_requests)
    assert Brew.where.not(method: "espresso", recipient_kind: "guest").all? { |item| item.cupping_request.nil? }
  end

  test "restorer preserves provided capabilities and fills a partial cupping collection without duplicates" do
    first_brew = create_restore_recipient_brew(
      recipient_kind: "guest", recipient_name: "Preserved Guest", cup_style: "First Cup",
      notes: "partial preserved cupping"
    )
    second_brew = create_restore_recipient_brew(
      recipient_kind: "guest", recipient_name: "Reconciled Guest", cup_style: "Second Cup",
      notes: "partial missing cupping"
    )
    first_request = CuppingRequests::Synchronize.call(first_brew)
    second_request = CuppingRequests::Synchronize.call(second_brew)
    first_snapshot = first_request.snapshot.deep_dup
    archive_bytes = InstanceBackupArchiveBuilder.new.call
    partial_archive = mutate_backup_payload(archive_bytes) do |payload|
      workspace_payload = payload.fetch("workspaces").find do |item|
        item.dig("workspace", "id") == first_brew.workspace_id
      end
      workspace_payload["cupping_requests"].select! { |row| row.fetch("id") == first_request.id }
    end

    empty_instance!
    summary = InstanceBackupRestorer.new(partial_archive).call

    preserved = CuppingRequest.find_by_token!(first_request.token)
    reconciled_brew = Brew.find_by!(notes: "partial missing cupping")
    reconciled = reconciled_brew.cupping_request
    assert_equal first_snapshot, preserved.snapshot
    assert reconciled
    assert_not_equal second_request.token, reconciled.token
    assert_equal 1, CuppingRequest.where(brew_id: preserved.brew_id).count
    assert_equal 1, CuppingRequest.where(brew_id: reconciled_brew.id).count
    assert_equal Brew.where(method: "espresso", recipient_kind: "guest").count, CuppingRequest.count
    assert_equal CuppingRequest.count, summary.fetch(:cupping_requests)
    assert Brew.where.not(method: "espresso", recipient_kind: "guest").all? { |item| item.cupping_request.nil? }
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

  test "restorer tombstones a workspace account event when its user subject is no longer a member" do
    workspace = workspaces(:household)
    former_member = User.create!(
      email_address: "former-account-event-member@example.com",
      password: "password",
      display_name: "Former Account Event Member"
    )
    membership = workspace.memberships.create!(user: former_member, role: "member")
    source_event = Activity::Emitter.record!(
      action: "profile.updated", workspace:, actor: former_member, subject: former_member,
      occurred_at: Time.zone.parse("2026-08-20 13:14:15")
    )
    source_metadata = source_event.metadata.deep_dup
    membership.destroy!
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call

    empty_instance!
    InstanceBackupRestorer.new(archive_bytes).call

    restored_workspace = Workspace.find_by!(name: workspace.name)
    restored_user = User.find_by!(email_address: former_member.email_address)
    restored_event = ActivityEvent.find_by!(workspace: restored_workspace, action: "profile.updated")
    assert_not restored_workspace.memberships.exists?(user: restored_user)
    assert_equal restored_user, restored_event.actor
    assert_nil restored_event.subject
    assert_equal source_metadata, restored_event.metadata
    assert_equal source_event.occurred_at, restored_event.occurred_at
  end

  test "restorer supports legacy serving rows and exact new field precedence" do
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-23 12:00:00")
    ).call
    compatible_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "id") == workspaces(:household).id
      end
      base = household.fetch("brews").find { |row| row.fetch("id") == brews(:morning_espresso).id }
      next_id = household.fetch("brews").map { |row| row.fetch("id") }.max + 100
      rows = [
        legacy_brew_row(
          base, id: next_id, notes: "legacy true", served_for_guest: true,
          guest_name: "  Legacy Anna  ", cup_style: "Legacy Cup"
        ),
        legacy_brew_row(
          base, id: next_id + 1, notes: "legacy false", served_for_guest: false,
          guest_name: "Discard Me", cup_style: "Legacy Self Cup"
        ),
        earliest_brew_row(base, id: next_id + 2, notes: "earliest v1"),
        new_guest_with_legacy_fallback_row(
          base, id: next_id + 3, notes: "new guest legacy fallback", guest_name: "Fallback Anna"
        ),
        base.deep_dup.merge(
          "id" => next_id + 4,
          "notes" => "new guest explicit nil",
          "recipient_kind" => "guest",
          "recipient_name" => nil,
          "served_for_guest" => true,
          "guest_name" => "Stale Anna",
          "cup_style" => "Explicit Nil Cup"
        ),
        base.deep_dup.merge(
          "id" => next_id + 5,
          "notes" => "new self wins",
          "recipient_kind" => "self",
          "recipient_name" => "Stale New Name",
          "served_for_guest" => true,
          "guest_name" => "Stale Legacy Name",
          "cup_style" => "New Self Cup"
        ),
        legacy_brew_row(
          base, id: next_id + 6, notes: "legacy nil", served_for_guest: nil,
          guest_name: "Discard Nil Guest", cup_style: "Legacy Nil Cup"
        )
      ]
      household.fetch("brews").concat(rows)
    end

    empty_instance!
    InstanceBackupRestorer.new(compatible_archive).call

    legacy_guest = Brew.find_by!(notes: "legacy true")
    assert_predicate legacy_guest, :recipient_guest?
    assert_equal "Legacy Anna", legacy_guest.recipient_name
    assert_equal "Legacy Cup", legacy_guest.cup_style
    legacy_self = Brew.find_by!(notes: "legacy false")
    assert_predicate legacy_self, :recipient_self?
    assert_nil legacy_self.recipient_name
    assert_nil legacy_self.recipient_user
    assert_equal "Legacy Self Cup", legacy_self.cup_style
    earliest = Brew.find_by!(notes: "earliest v1")
    assert_predicate earliest, :recipient_self?
    assert_nil earliest.recipient_name
    assert_nil earliest.recipient_user
    assert_nil earliest.cup_style
    fallback = Brew.find_by!(notes: "new guest legacy fallback")
    assert_predicate fallback, :recipient_guest?
    assert_equal "Fallback Anna", fallback.recipient_name
    explicit_nil = Brew.find_by!(notes: "new guest explicit nil")
    assert_predicate explicit_nil, :recipient_guest?
    assert_nil explicit_nil.recipient_name
    assert_equal "Explicit Nil Cup", explicit_nil.cup_style
    new_self = Brew.find_by!(notes: "new self wins")
    assert_predicate new_self, :recipient_self?
    assert_nil new_self.recipient_user
    assert_nil new_self.recipient_name
    assert_equal "New Self Cup", new_self.cup_style
    legacy_nil = Brew.find_by!(notes: "legacy nil")
    assert_predicate legacy_nil, :recipient_self?
    assert_nil legacy_nil.recipient_user
    assert_nil legacy_nil.recipient_name
    assert_equal "Legacy Nil Cup", legacy_nil.cup_style
  end

  test "restorer maps household recipients only by archived user id" do
    logger = users(:one)
    recipient = users(:two)
    recipient.update!(display_name: "Intended Recipient")
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: recipient, notes: "id mapped recipient")
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-23 12:00:00")
    ).call
    tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "id") == workspaces(:household).id
      end
      row = household.fetch("brews").find { |item| item.fetch("id") == brew.id }
      row["recipient_user_display_name"] = logger.display_label
      row["recipient_user_email_address"] = logger.email_address
    end

    empty_instance!
    InstanceBackupRestorer.new(tampered_archive).call

    restored = Brew.find_by!(notes: "id mapped recipient")
    assert_equal recipient.email_address, restored.recipient_user.email_address
    assert_not_equal logger.email_address, restored.recipient_user.email_address
  end

  test "malformed recipient and cup data raises sanitized restore error with full rollback" do
    attachment = attach_photo(beans(:open_household))
    source_workspace_id = workspaces(:household).id
    source_brew_id = brews(:morning_espresso).id
    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-23 12:00:00")
    ).call
    mutations = {
      unsupported_kind: ->(row) { row["recipient_kind"] = "hostile-kind" },
      whitespace_padded_kind: ->(row) { row["recipient_kind"] = " guest " },
      malformed_legacy_flag: lambda do |row|
        remove_new_recipient_fields(row)
        row["served_for_guest"] = "true"
      end,
      missing_household_id: lambda do |row|
        row["recipient_kind"] = "household_member"
        row["recipient_user_id"] = nil
      end,
      unknown_household_id: lambda do |row|
        row["recipient_kind"] = "household_member"
        row["recipient_user_id"] = 999_999_999
      end,
      logger_as_recipient: lambda do |row|
        row["recipient_kind"] = "household_member"
        row["recipient_user_id"] = row.fetch("user_id")
      end,
      non_string_recipient_name: lambda do |row|
        row["recipient_kind"] = "guest"
        row["recipient_name"] = { "secret" => "Private Guest Object" }
      end,
      non_string_legacy_guest_name: lambda do |row|
        remove_new_recipient_fields(row)
        row["served_for_guest"] = true
        row["guest_name"] = [ "Private Legacy Guest" ]
      end,
      overlong_recipient_name: lambda do |row|
        row["recipient_kind"] = "guest"
        row["recipient_name"] = "Private Guest " + ("x" * 121)
      end,
      non_string_cup_style: ->(row) { row["cup_style"] = [ "Private Cup" ] },
      overlong_cup_style: ->(row) { row["cup_style"] = "Private Cup " + ("x" * 121) }
    }
    tampered_archives = mutations.transform_values do |mutation|
      mutate_backup_payload(archive_bytes) do |payload|
        household = payload.fetch("workspaces").find do |workspace_payload|
          workspace_payload.dig("workspace", "id") == source_workspace_id
        end
        row = household.fetch("brews").find { |item| item.fetch("id") == source_brew_id }
        mutation.call(row)
      end
    end

    tampered_archives.each do |case_name, tampered_archive|
      empty_instance!
      starting_counts = restore_boundary_counts

      error = assert_raises(InstanceBackupRestorer::RestoreError, case_name.to_s) do
        InstanceBackupRestorer.new(tampered_archive).call
      end

      assert_equal "Invalid brew recipient data", error.message, case_name.to_s
      assert_no_match(/Private|999999999|#{attachment.id}|#{attachment.blob_id}/, error.message, case_name.to_s)
      assert_equal starting_counts, restore_boundary_counts, case_name.to_s
      assert_equal 0, ActiveStorage::Attachment.count, case_name.to_s
      assert_equal 0, ActiveStorage::Blob.count, case_name.to_s
    end
  end

  private
    def build_backup_cupping_request(notes:, opened_at:, feedback_expires_at:, closed_at: nil,
      expiration_job_enqueued_at: nil, expiration_job_enqueueing_at: nil, feedback_comment: nil, last_guest_ip: nil)
      brew = create_restore_recipient_brew(
        recipient_kind: "guest",
        recipient_name: "Backup Guest",
        cup_style: "Cupping Bowl",
        notes:
      )
      request = CuppingRequests::Synchronize.call(brew)
      request.update_columns(
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:, title: PublicBrewShare.default_title_for(brew), selected_photo_attachment_ids: []
        ).call,
        opened_at:,
        feedback_expires_at:,
        closed_at:,
        expiration_job_enqueued_at:,
        expiration_job_enqueueing_at:,
        feedback_comment:,
        last_guest_ip:
      )
      request.update_columns(
        created_at: request.created_at.change(usec: 0),
        updated_at: request.updated_at.change(usec: 0)
      )
      request.reload
    end

    def cupping_request_row(payload, request)
      workspace_payload = payload.fetch("workspaces").find do |item|
        item.dig("workspace", "id") == request.workspace_id
      end
      workspace_payload.fetch("cupping_requests").find { |row| row.fetch("id") == request.id }
    end

    def create_restore_recipient_brew(recipient_kind:, recipient_user: nil, recipient_name: nil, cup_style:, notes:)
      workspaces(:household).brews.create!(
        user: users(:one),
        bean: beans(:open_household),
        method: "espresso",
        bean_weight_grams: 1,
        recipient_kind:,
        recipient_user:,
        recipient_name:,
        cup_style:,
        notes:
      )
    end

    def legacy_brew_row(base, id:, notes:, served_for_guest:, guest_name:, cup_style:)
      base.deep_dup.tap do |row|
        row["id"] = id
        row["notes"] = notes
        remove_new_recipient_fields(row)
        row["served_for_guest"] = served_for_guest
        row["guest_name"] = guest_name
        row["cup_style"] = cup_style
      end
    end

    def earliest_brew_row(base, id:, notes:)
      base.deep_dup.tap do |row|
        row["id"] = id
        row["notes"] = notes
        remove_new_recipient_fields(row)
        row.delete("served_for_guest")
        row.delete("guest_name")
        row.delete("cup_style")
      end
    end

    def new_guest_with_legacy_fallback_row(base, id:, notes:, guest_name:)
      base.deep_dup.tap do |row|
        row["id"] = id
        row["notes"] = notes
        row["recipient_kind"] = "guest"
        row.delete("recipient_name")
        row["served_for_guest"] = true
        row["guest_name"] = guest_name
      end
    end

    def remove_new_recipient_fields(row)
      %w[
        recipient_kind recipient_user_id recipient_user_display_name recipient_user_email_address recipient_name
      ].each { |key| row.delete(key) }
    end

    def restore_boundary_counts
      {
        users: User.count,
        workspaces: Workspace.count,
        memberships: Membership.count,
        beans: Bean.count,
        brews: Brew.count,
        inventory_adjustments: InventoryAdjustment.count,
        activity_events: ActivityEvent.count,
        attachments: ActiveStorage::Attachment.count,
        blobs: ActiveStorage::Blob.count
      }
    end

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
      CuppingRequest.delete_all
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
