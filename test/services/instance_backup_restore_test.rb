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
      active_workspace: workspaces(:household)
    )
    source_bean = beans(:open_household)
    source_bean_finished_at = Time.zone.parse("2026-05-24 18:30:00")
    source_bean.update!(remaining_grams: 14, finished_at: source_bean_finished_at)
    duplicated_bean = source_bean.duplicate_for_new_bag!
    duplicated_bean.update!(name: "Restored duplicate bag")
    attachment = attach_photo(beans(:open_household))
    original = {
      users: User.count,
      workspaces: Workspace.count,
      beans: Bean.count,
      brews: Brew.count,
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
      duplicated_bean_name: duplicated_bean.name,
      photo_filename: attachment.blob.filename.to_s
    }
    archive_bytes = InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call

    empty_instance!
    summary = InstanceBackupRestorer.new(archive_bytes).call

    restored_user = User.find_by!(email_address: original.fetch(:user_email))
    restored_workspace = Workspace.find_by!(name: original.fetch(:workspace_name))
    restored_bean = Bean.find_by!(name: original.fetch(:bean_name))
    restored_duplicate_bean = Bean.find_by!(name: original.fetch(:duplicated_bean_name))

    assert_equal original.fetch(:users), User.count
    assert_equal original.fetch(:workspaces), Workspace.count
    assert_equal original.fetch(:beans), Bean.count
    assert_equal original.fetch(:brews), Brew.count
    assert_equal original.fetch(:equipment), Equipment.count
    assert_equal original.fetch(:inventory_adjustments), InventoryAdjustment.count
    assert_equal original.fetch(:attachments), ActiveStorage::Attachment.count
    assert_not_equal original.fetch(:user_id), restored_user.id
    assert_not_equal original.fetch(:workspace_id), restored_workspace.id
    assert_not_equal original.fetch(:password_digest), restored_user.password_digest
    assert_equal "Restore Admin", restored_user.display_name
    assert_predicate restored_user, :instance_admin?
    assert_equal restored_workspace, restored_user.active_workspace
    assert_equal original.fetch(:bean_finished_at).to_i, restored_bean.finished_at.to_i
    assert_equal "finished", restored_bean.bag_status
    assert_equal original.fetch(:photo_filename), restored_bean.photos.first.filename.to_s
    assert_equal restored_bean, restored_duplicate_bean.duplicated_from_bean
    assert_equal(
      {
        users: original.fetch(:users),
        workspaces: original.fetch(:workspaces),
        beans: original.fetch(:beans),
        brews: original.fetch(:brews),
        media_files: original.fetch(:attachments)
      },
      summary.slice(:users, :workspaces, :beans, :brews, :media_files)
    )
  end

  private
    def empty_instance!
      ActiveStorage::VariantRecord.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Session.delete_all
      WorkspaceInvite.delete_all
      InventoryAdjustment.delete_all
      BrewPreparationTool.delete_all
      EquipmentEventItem.delete_all
      EquipmentEvent.delete_all
      Brew.delete_all
      PreparationTool.delete_all
      Equipment.delete_all
      Bean.delete_all
      DataImport.delete_all
      Membership.delete_all
      User.update_all(active_workspace_id: nil)
      Workspace.delete_all
      User.delete_all
    end
end
