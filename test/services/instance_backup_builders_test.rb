require "test_helper"
require "zip"

class InstanceBackupBuildersTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "readable export includes instance data without live secrets" do
    user = users(:one)
    user.update!(display_name: "Jens", instance_admin: true)
    attach_named_photo(user, :avatar, filename: "avatar.jpg")
    attach_named_photo(workspaces(:household), :logo, filename: "household-logo.jpg")
    invite = workspace_invites(:member_invite)

    payload = InstanceReadableExportBuilder.new(generated_at: Time.zone.parse("2026-05-27 12:00:00")).call
    json = JSON.pretty_generate(payload)

    assert_equal "roastnode.instance_readable_export", payload.fetch(:format)
    assert_equal [ workspaces(:household).id, workspaces(:other_household).id ].sort,
      payload.fetch(:workspaces).map { |workspace| workspace.fetch(:workspace).fetch(:id) }.sort
    assert_equal user.email_address, payload.fetch(:users).find { |row| row.fetch(:id) == user.id }.fetch(:email_address)
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
