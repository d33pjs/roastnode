require "test_helper"
require "zip"

class InstanceBackupBuildersTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "readable export includes instance data without live secrets" do
    user = users(:one)
    user.update!(
      display_name: "Jens",
      instance_admin: true,
      enabled_brew_methods: [ "quick_drip" ],
      grams_per_coffee_spoon: 4.5
    )
    finished_at = Time.zone.parse("2026-05-24 18:30:00")
    beans(:open_household).update!(
      remaining_grams: 14,
      finished_at:,
      purchase_url: "https://shop.example/house-blend",
      coffee_origin_url: "https://origin.example/house-blend"
    )
    beans(:second_open_household).update!(grind_state: "pre_ground")
    quick_drip = workspaces(:household).brews.create!(
      user:,
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      recipient_kind: "guest",
      recipient_name: "Anna",
      cup_style: "Batch Brew"
    )
    external_coffee = workspaces(:household).external_coffees.create!(
      user:,
      drink_type: "Flat White",
      place_name: "Local Shop",
      price_cents: 450,
      currency: "EUR",
      acidity_balance: "balanced",
      intensity: "strong",
      rating: 4
    )
    attach_named_photo(user, :avatar, filename: "avatar.jpg")
    attach_named_photo(workspaces(:household), :logo, filename: "household-logo.jpg")
    invite = workspace_invites(:member_invite)

    payload = InstanceReadableExportBuilder.new(generated_at: Time.zone.parse("2026-05-27 12:00:00")).call
    json = JSON.pretty_generate(payload)

    assert_equal "roastnode.instance_readable_export", payload.fetch(:format)
    assert_equal 1, payload.fetch(:version)
    assert_equal [ workspaces(:household).id, workspaces(:other_household).id ].sort,
      payload.fetch(:workspaces).map { |workspace| workspace.fetch(:workspace).fetch(:id) }.sort
    user_payload = payload.fetch(:users).find { |row| row.fetch(:id) == user.id }
    assert_equal user.email_address, user_payload.fetch(:email_address)
    assert_equal [ "quick_drip" ], user_payload.fetch(:enabled_brew_methods)
    assert_equal "4.5", user_payload.fetch(:grams_per_coffee_spoon)
    household_payload = payload.fetch(:workspaces).find { |workspace| workspace.fetch(:workspace).fetch(:id) == workspaces(:household).id }
    assert_equal 1, household_payload.fetch(:version)
    bean_payload = household_payload.fetch(:beans).find { |bean| bean.fetch(:id) == beans(:open_household).id }
    assert_equal "finished", bean_payload.fetch(:status)
    assert_equal finished_at.iso8601, bean_payload.fetch(:finished_at)
    assert_equal "https://shop.example/house-blend", bean_payload.fetch(:purchase_url)
    assert_equal "https://origin.example/house-blend", bean_payload.fetch(:coffee_origin_url)
    pre_ground_payload = household_payload.fetch(:beans).find { |bean| bean.fetch(:id) == beans(:second_open_household).id }
    assert_equal "pre_ground", pre_ground_payload.fetch(:grind_state)
    brew_payload = household_payload.fetch(:brews).find { |brew| brew.fetch(:id) == quick_drip.id }
    assert_equal equipment(:household_brewer).id, brew_payload.fetch(:brewer_id)
    assert_equal "6.0", brew_payload.fetch(:machine_cups)
    assert_equal "6.0", brew_payload.fetch(:coffee_spoons)
    assert_equal "4.5", brew_payload.fetch(:grams_per_coffee_spoon)
    assert_equal "estimated_spoons", brew_payload.fetch(:coffee_amount_source)
    assert_equal(
      {
        recipient_kind: "guest",
        recipient_user_id: nil,
        recipient_user_display_name: nil,
        recipient_user_email_address: nil,
        recipient_name: "Anna",
        cup_style: "Batch Brew"
      },
      brew_payload.slice(
        :recipient_kind, :recipient_user_id, :recipient_user_display_name,
        :recipient_user_email_address, :recipient_name, :cup_style
      )
    )
    assert_not brew_payload.key?(:served_for_guest)
    assert_not brew_payload.key?(:guest_name)
    external_coffee_payload = household_payload.fetch(:external_coffees).find { |coffee| coffee.fetch(:id) == external_coffee.id }
    assert_equal "Flat White", external_coffee_payload.fetch(:drink_type)
    assert_equal "Local Shop", external_coffee_payload.fetch(:place_name)
    assert_equal 450, external_coffee_payload.fetch(:price_cents)
    assert_equal "strong", external_coffee_payload.fetch(:intensity)
    assert_match(%r{media/users/#{user.id}/avatar/}, json)
    assert_match(%r{media/workspaces/#{workspaces(:household).id}/logo/}, json)
    assert_no_match(/password_digest/i, json)
    assert_no_match(user.password_digest, json)
    assert_no_match(/session/i, json)
    assert_no_match(invite.token, json)
    assert_no_match(/rails\/active_storage|signed_id|signed/i, json)
  end

  test "full archive writes manifest readable export and media files" do
    attachment = attach_photo(beans(:open_household))
    brew = brews(:morning_espresso)
    users(:two).update!(display_name: "Full Archive Recipient")
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two), cup_style: "Cortado")

    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-27 12:00:00")).call
    entries = {}

    Zip::File.open_buffer(archive_bytes) do |zip|
      zip.each do |entry|
        entries[entry.name] = entry.get_input_stream.read
      end
    end

    manifest = JSON.parse(entries.fetch("manifest.json"))
    export = JSON.parse(entries.fetch("data/instance-readable-export.json"))
    media_path = manifest.fetch("files").find { |file| file.fetch("attachment_id") == attachment.id }.fetch("path")

    assert_equal "roastnode.instance_backup_archive", manifest.fetch("format")
    assert_equal 1, manifest.fetch("version")
    assert_equal 1, manifest.fetch("data").fetch("version")
    assert_equal "roastnode.instance_readable_export", export.fetch("format")
    assert_equal 1, export.fetch("version")
    household = export.fetch("workspaces").find do |workspace_payload|
      workspace_payload.dig("workspace", "id") == workspaces(:household).id
    end
    exported_brew = household.fetch("brews").find { |row| row.fetch("id") == brew.id }
    assert_equal(
      [ "household_member", users(:two).id, "Full Archive Recipient", users(:two).email_address, nil, "Cortado" ],
      %w[recipient_kind recipient_user_id recipient_user_display_name recipient_user_email_address recipient_name cup_style]
        .map { |key| exported_brew[key] }
    )
    assert_equal attachment.blob.download, entries.fetch(media_path)
    assert_equal Digest::SHA256.hexdigest(attachment.blob.download),
      manifest.fetch("files").find { |file| file.fetch("path") == media_path }.fetch("sha256")
  end

  test "readable and full backups preserve workspace scoped cupping request state" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Backup Guest")
    request = CuppingRequests::Synchronize.call(brew)
    opened_at = Time.zone.parse("2026-08-28 10:00:00")
    expires_at = opened_at + 24.hours
    enqueued_at = opened_at + 1.minute
    enqueueing_at = opened_at + 30.seconds
    request.update_columns(
      snapshot: { "title" => "Archived cupping page", "brew" => { "method" => "espresso" } },
      feedback_comment: "Private archived feedback",
      opened_at:,
      feedback_expires_at: expires_at,
      last_guest_ip: "203.0.113.44",
      expiration_job_enqueued_at: enqueued_at,
      expiration_job_enqueueing_at: enqueueing_at
    )

    readable = InstanceReadableExportBuilder.new(generated_at: Time.zone.parse("2026-08-28 12:00:00")).call
    household = readable.fetch(:workspaces).find do |workspace_payload|
      workspace_payload.dig(:workspace, :id) == brew.workspace_id
    end
    row = household.fetch(:cupping_requests).find { |item| item.fetch(:id) == request.id }

    assert_equal(
      {
        id: request.id,
        workspace_id: brew.workspace_id,
        brew_id: brew.id,
        token: request.token,
        token_digest: request.token_digest,
        snapshot: request.snapshot,
        feedback_comment: "Private archived feedback",
        opened_at: opened_at.iso8601,
        feedback_expires_at: expires_at.iso8601,
        closed_at: nil,
        last_guest_ip: "203.0.113.44",
        expiration_job_enqueued_at: enqueued_at.iso8601,
        expiration_job_enqueueing_at: enqueueing_at.iso8601,
        created_at: request.created_at.iso8601,
        updated_at: request.updated_at.iso8601
      },
      row
    )
    assert household.fetch(:cupping_requests).all? { |item| item.fetch(:workspace_id) == brew.workspace_id }

    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-08-28 12:00:00")).call
    Zip::File.open_buffer(archive_bytes) do |zip|
      archived = JSON.parse(zip.read("data/instance-readable-export.json"))
      archived_household = archived.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "id") == brew.workspace_id
      end
      archived_row = archived_household.fetch("cupping_requests").find { |item| item.fetch("id") == request.id }

      assert_equal request.token, archived_row.fetch("token")
      assert_equal request.token_digest, archived_row.fetch("token_digest")
      assert_equal "Private archived feedback", archived_row.fetch("feedback_comment")
      assert_equal enqueueing_at.iso8601, archived_row.fetch("expiration_job_enqueueing_at")
    end
  end

  test "readable and full archive exports preserve workspace and instance activity" do
    readable = InstanceReadableExportBuilder.new(generated_at: Time.zone.parse("2026-08-21 12:00:00")).call
    household = readable.fetch(:workspaces).find do |workspace_payload|
      workspace_payload.dig(:workspace, :id) == workspaces(:household).id
    end

    assert_includes household.fetch(:activity_events).map { |row| row.fetch(:id) },
      activity_events(:morning_brew_created).id
    assert_includes readable.fetch(:instance_activity_events).map { |row| row.fetch(:id) },
      activity_events(:scheduled_backup_succeeded).id

    archive_bytes = InstanceBackupArchiveBuilder.new(
      generated_at: Time.zone.parse("2026-08-21 12:00:00")
    ).call
    Zip::File.open_buffer(archive_bytes) do |zip|
      archived = JSON.parse(zip.read("data/instance-readable-export.json"))
      archived_household = archived.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "id") == workspaces(:household).id
      end

      assert_includes archived_household.fetch("activity_events").map { |row| row.fetch("id") },
        activity_events(:morning_brew_created).id
      assert_includes archived.fetch("instance_activity_events").map { |row| row.fetch("id") },
        activity_events(:scheduled_backup_succeeded).id
    end
  end
end
