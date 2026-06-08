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
    beans(:open_household).update!(remaining_grams: 14, finished_at:)
    beans(:second_open_household).update!(grind_state: "pre_ground")
    quick_drip = workspaces(:household).brews.create!(
      user:,
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )
    attach_named_photo(user, :avatar, filename: "avatar.jpg")
    attach_named_photo(workspaces(:household), :logo, filename: "household-logo.jpg")
    invite = workspace_invites(:member_invite)

    payload = InstanceReadableExportBuilder.new(generated_at: Time.zone.parse("2026-05-27 12:00:00")).call
    json = JSON.pretty_generate(payload)

    assert_equal "roastnode.instance_readable_export", payload.fetch(:format)
    assert_equal [ workspaces(:household).id, workspaces(:other_household).id ].sort,
      payload.fetch(:workspaces).map { |workspace| workspace.fetch(:workspace).fetch(:id) }.sort
    user_payload = payload.fetch(:users).find { |row| row.fetch(:id) == user.id }
    assert_equal user.email_address, user_payload.fetch(:email_address)
    assert_equal [ "quick_drip" ], user_payload.fetch(:enabled_brew_methods)
    assert_equal "4.5", user_payload.fetch(:grams_per_coffee_spoon)
    household_payload = payload.fetch(:workspaces).find { |workspace| workspace.fetch(:workspace).fetch(:id) == workspaces(:household).id }
    bean_payload = household_payload.fetch(:beans).find { |bean| bean.fetch(:id) == beans(:open_household).id }
    assert_equal "finished", bean_payload.fetch(:status)
    assert_equal finished_at.iso8601, bean_payload.fetch(:finished_at)
    pre_ground_payload = household_payload.fetch(:beans).find { |bean| bean.fetch(:id) == beans(:second_open_household).id }
    assert_equal "pre_ground", pre_ground_payload.fetch(:grind_state)
    brew_payload = household_payload.fetch(:brews).find { |brew| brew.fetch(:id) == quick_drip.id }
    assert_equal equipment(:household_brewer).id, brew_payload.fetch(:brewer_id)
    assert_equal "6.0", brew_payload.fetch(:machine_cups)
    assert_equal "6.0", brew_payload.fetch(:coffee_spoons)
    assert_equal "4.5", brew_payload.fetch(:grams_per_coffee_spoon)
    assert_equal "estimated_spoons", brew_payload.fetch(:coffee_amount_source)
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
    assert_equal "roastnode.instance_readable_export", export.fetch("format")
    assert_equal attachment.blob.download, entries.fetch(media_path)
    assert_equal Digest::SHA256.hexdigest(attachment.blob.download),
      manifest.fetch("files").find { |file| file.fetch("path") == media_path }.fetch("sha256")
  end
end
