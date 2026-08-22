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

  test "instance admin profile mutations and manual queue emit safe instance activity" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    created_event = assert_activity_event(
      action: "instance_backup_profile.created", workspace: nil, actor: admin
    ) do
      post instance_admin_backup_profiles_path, params: {
        instance_backup_profile: {
          backup_kind: "full_archive", name: "Nightly full archive", enabled: "1",
          schedule: "daily", storage_path: "storage/private-location", retention_count: "3"
        }
      }
    end
    profile = InstanceBackupProfile.order(:id).last
    assert_equal profile, created_event.subject
    assert_equal "full_archive", created_event.metadata.fetch("backup_kind")
    assert_no_match(/storage|private|location|file_path/i, created_event.metadata.to_json)

    updated_event = assert_activity_event(
      action: "instance_backup_profile.updated", workspace: nil, actor: admin, subject: profile
    ) do
      patch instance_admin_backup_profile_path(profile), params: {
        instance_backup_profile: {
          backup_kind: "readable_json", name: "Readable backup", enabled: "0",
          schedule: "weekly", storage_path: "storage/another-location", retention_count: "4"
        }
      }
    end
    assert_equal "readable_json", updated_event.metadata.fetch("backup_kind")
    assert_no_match(/storage|location|file_path/i, updated_event.metadata.to_json)

    queued_event = assert_activity_event(
      action: "instance_backup_run.queued", workspace: nil, actor: admin
    ) do
      assert_enqueued_with(job: InstanceBackupJob) do
        post run_instance_admin_backup_profile_path(profile)
      end
    end
    assert_equal profile.instance_backup_runs.last, queued_event.subject
    assert_equal "queued", queued_event.metadata.fetch("status")
  end

  test "profile activity failure rolls back the profile update" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    profile = InstanceBackupProfile.create!(
      name: "Original", backup_kind: "full_archive", enabled: true, schedule: "daily",
      storage_path: "storage/instance_backups", retention_count: 7
    )
    sign_in_as(admin)
    failure = lambda do |**|
      raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
    end

    assert_no_difference -> { ActivityEvent.count } do
      with_stubbed_singleton_method(Activity::Emitter, :record!, failure) do
        patch instance_admin_backup_profile_path(profile), params: {
          instance_backup_profile: {
            name: "Changed", enabled: "0", schedule: "weekly",
            storage_path: "storage/changed", retention_count: "2"
          }
        }
        assert_response :unprocessable_content
      end
    end

    assert_equal "Original", profile.reload.name
    assert_predicate profile, :enabled?
  end
end
