require "test_helper"

class InstanceBackupProfilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "regular users cannot create backup profiles" do
    sign_in_as(users(:one))

    post instance_admin_backup_profiles_path, params: {
      instance_backup_profile: {
        backup_kind: "full_archive",
        name: "Full archive",
        enabled: "1",
        schedule: "daily",
        retention_count: "7"
      }
    }

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
    assert_equal 0, InstanceBackupProfile.count
  end

  test "instance admins can create configure and run backup profiles" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_difference("InstanceBackupProfile.count", 1) do
      post instance_admin_backup_profiles_path, params: {
        instance_backup_profile: {
          backup_kind: "full_archive",
          name: "Nightly full archive",
          enabled: "1",
          schedule: "daily",
          storage_path: "tmp/test-instance-backups",
          retention_count: "3"
        }
      }
    end

    profile = InstanceBackupProfile.last
    assert_equal "full_archive", profile.backup_kind
    assert_predicate profile, :enabled?
    assert_equal "daily", profile.schedule
    assert_equal 3, profile.retention_count

    patch instance_admin_backup_profile_path(profile), params: {
      instance_backup_profile: {
        name: "Weekly archive",
        enabled: "0",
        schedule: "weekly",
        storage_path: "storage/backups",
        retention_count: "4"
      }
    }

    profile.reload
    assert_equal "Weekly archive", profile.name
    assert_not profile.enabled?
    assert_equal "weekly", profile.schedule
    assert_equal "storage/backups", profile.storage_path
    assert_equal 4, profile.retention_count

    assert_enqueued_with(job: InstanceBackupJob) do
      post run_instance_admin_backup_profile_path(profile)
    end
    assert_equal 1, profile.instance_backup_runs.count
    assert_equal "queued", profile.instance_backup_runs.last.status
  end
end
