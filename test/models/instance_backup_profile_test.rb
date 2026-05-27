require "test_helper"

class InstanceBackupProfileTest < ActiveSupport::TestCase
  test "validates backup kind schedule and retention" do
    profile = InstanceBackupProfile.new(
      name: "Nightly backup",
      backup_kind: "unknown",
      schedule: "hourly",
      retention_count: 0
    )

    assert_not profile.valid?
    assert_includes profile.errors[:backup_kind], "is not included in the list"
    assert_includes profile.errors[:schedule], "is not included in the list"
    assert_includes profile.errors[:retention_count], "must be greater than or equal to 1"
  end

  test "detects due enabled daily profiles" do
    profile = InstanceBackupProfile.create!(
      name: "Daily full archive",
      backup_kind: "full_archive",
      enabled: true,
      schedule: "daily",
      retention_count: 7,
      last_enqueued_at: Time.zone.parse("2026-05-26 08:00:00")
    )

    assert profile.due_for_enqueue?(Time.zone.parse("2026-05-27 08:00:01"))
    assert_not profile.due_for_enqueue?(Time.zone.parse("2026-05-27 07:59:59"))
  end

  test "does not enqueue disabled or manual profiles" do
    disabled = InstanceBackupProfile.create!(
      name: "Disabled backup",
      backup_kind: "full_archive",
      enabled: false,
      schedule: "daily",
      retention_count: 7
    )
    manual = InstanceBackupProfile.create!(
      name: "Manual readable export",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "manual",
      retention_count: 7
    )

    assert_not disabled.due_for_enqueue?(Time.current)
    assert_not manual.due_for_enqueue?(Time.current)
  end
end
