require "test_helper"

class InstanceAdminControllerTest < ActionDispatch::IntegrationTest
  test "redirects anonymous visitors to sign in" do
    get "/instance_admin"

    assert_redirected_to new_session_path
  end

  test "redirects regular users away from the instance admin dashboard" do
    sign_in_as(users(:one))

    get "/instance_admin"

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
  end

  test "shows private instance status and aggregate counts to instance admins" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    get "/instance_admin"

    assert_response :success
    assert_select "h1", I18n.t("instance_admin.index.title")
    assert_select "[data-testid=instance-admin-status]", text: /#{I18n.t("instance_admin.index.private_mode")}/
    assert_select "[data-testid=instance-admin-public-registration]", text: /#{I18n.t("instance_admin.index.disabled")}/
    assert_select "[data-testid=instance-admin-demo-data]", text: /bin\/rails roastnode:demo:load/
    assert_select "[data-testid=instance-admin-metric-users]", text: /#{User.count}/
    assert_select "[data-testid=instance-admin-metric-workspaces]", text: /#{Workspace.count}/
    assert_select "[data-testid=instance-admin-metric-beans]", text: /#{Bean.count}/
    assert_select "[data-testid=instance-admin-metric-brews]", text: /#{Brew.count}/
    assert_select "[data-testid=instance-admin-metric-equipment]", text: /#{Equipment.count}/
    assert_no_match(/password_digest|session|invite token/i, response.body)
    assert_no_match(admin.password_digest, response.body)
  end

  test "shows read-only instance health checks to instance admins" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    get "/instance_admin"

    assert_response :success
    assert_select "h2", I18n.t("instance_admin.index.health")
    assert_select "[data-testid=instance-admin-health-database]", text: /#{I18n.t("instance_admin.index.health_labels.database")}/
    assert_select "[data-testid=instance-admin-health-database]", text: /#{I18n.t("instance_admin.index.ok")}/
    assert_select "[data-testid=instance-admin-health-storage]", text: /#{I18n.t("instance_admin.index.health_labels.storage")}/
    assert_select "[data-testid=instance-admin-health-storage]", text: /#{ActiveStorage::Blob.service.name}/
    assert_select "[data-testid=instance-admin-health-storage_usage]", text: /#{I18n.t("instance_admin.index.health_labels.storage_usage")}/
    assert_select "[data-testid=instance-admin-health-storage_usage]", text: /#{ActiveStorage::Blob.count}/
    assert_select "[data-testid=instance-admin-health-queue]", text: /#{I18n.t("instance_admin.index.health_labels.queue")}/
    assert_select "[data-testid=instance-admin-health-queue]", text: /#{Rails.application.config.active_job.queue_adapter}/
    assert_select "[data-testid=instance-admin-health-rails]", text: /#{I18n.t("instance_admin.index.health_labels.rails")}/
    assert_select "[data-testid=instance-admin-health-rails]", text: /#{Rails.version}/
  end

  test "shows operations status and redacted failures to instance admins" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    summary = Data.define(:key, :status, :value, :detail)
    mail_failure = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message).new(
      id: 987,
      class_name: "ActionMailer::MailDeliveryJob",
      queue_name: "mailers",
      failed_at: 7.minutes.ago,
      error_message: "Net::SMTPAuthenticationError: password=[REDACTED] token=[REDACTED]"
    )
    profile = InstanceBackupProfile.create!(
      name: "Readable backup",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "daily",
      storage_path: "tmp/test-instance-backups",
      retention_count: 7
    )
    failed_run = profile.instance_backup_runs.create!(
      backup_kind: profile.backup_kind,
      status: "failed",
      error_message: "RuntimeError: disk write failed password=super-secret",
      started_at: 10.minutes.ago,
      finished_at: 9.minutes.ago
    )
    backup_failure = Data.define(:id, :profile_name, :backup_kind, :failed_at, :error_message).new(
      id: failed_run.id,
      profile_name: profile.name,
      backup_kind: profile.backup_kind,
      failed_at: failed_run.finished_at,
      error_message: "RuntimeError: disk write failed password=[REDACTED]"
    )
    operations_snapshot = Object.new
    operations_snapshot.define_singleton_method(:queue_status) do
      summary.new(:background_jobs, :ok, I18n.t("instance_admin.index.operation_pending_jobs", count: 0), "0 failed / 0 blocked.")
    end
    operations_snapshot.define_singleton_method(:mail_status) do
      summary.new(:mail_delivery, :attention, "SMTP disabled", "SMTP is disabled.")
    end
    operations_snapshot.define_singleton_method(:backup_status) do
      summary.new(:backups, :attention, "1/2 enabled", "1 failed run needs attention.")
    end
    operations_snapshot.define_singleton_method(:export_status) do
      summary.new(:workspace_exports, :ok, "Owner-run", "Exports are available.")
    end
    operations_snapshot.define_singleton_method(:queue_counts) { [] }
    operations_snapshot.define_singleton_method(:failed_jobs) { [] }
    operations_snapshot.define_singleton_method(:mail_failures) { [ mail_failure ] }
    operations_snapshot.define_singleton_method(:backup_profile_rows) { [] }
    operations_snapshot.define_singleton_method(:backup_failures) { [ backup_failure ] }

    original_operations_snapshot_new = InstanceOperationsSnapshot.method(:new)
    InstanceOperationsSnapshot.define_singleton_method(:new) { operations_snapshot }
    begin
      get "/instance_admin"
    ensure
      InstanceOperationsSnapshot.define_singleton_method(:new, &original_operations_snapshot_new)
    end

    assert_response :success
    assert_select "h2", I18n.t("instance_admin.index.operations")
    assert_select "[data-testid=instance-admin-operations-queue]", text: /#{I18n.t("instance_admin.index.operation_labels.background_jobs")}/
    assert_select "[data-testid=instance-admin-operations-mail]", text: /#{I18n.t("instance_admin.index.operation_labels.mail_delivery")}/
    assert_select "[data-testid=instance-admin-mail-failure-#{mail_failure.id}]", text: /Net::SMTPAuthenticationError/
    assert_select "[data-testid=instance-admin-mail-failure-#{mail_failure.id}]", text: /\[REDACTED\]/
    assert_select "[data-testid=instance-admin-operations-backups]", text: /#{I18n.t("instance_admin.index.operation_labels.backups")}/
    assert_select "[data-testid=instance-admin-operations-export]", text: /#{I18n.t("instance_admin.index.operation_labels.workspace_exports")}/
    assert_select "[data-testid=instance-admin-backup-failure-#{failed_run.id}]", text: /RuntimeError/
    assert_select "[data-testid=instance-admin-backup-failure-#{failed_run.id}]", text: /\[REDACTED\]/
    assert_no_match(/super-secret|abc123/, response.body)
    assert_no_match(/password_digest|session|invite token/i, response.body)
  end

  test "shows household invite management to instance admins" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    get "/instance_admin"

    assert_response :success
    assert_select "[data-testid=instance-admin-household-invites]" do
      assert_select "form[action=?]", instance_admin_household_invites_path
      assert_select "input[name=?][type=email]", "household_invite[email_address]"
      assert_select "input[value=?]", household_invite_url(invite.token)
      assert_select "form[action=?]", resend_instance_admin_household_invite_path(invite.token)
      assert_select "form[action=?]", revoke_instance_admin_household_invite_path(invite.token)
    end
  end

  test "shows read-only account rows to instance admins" do
    admin = users(:one)
    admin.update!(display_name: "Jens", instance_admin: true)
    member = users(:two)
    member.update!(display_name: nil)
    sign_in_as(admin)

    get "/instance_admin"

    assert_response :success
    assert_select "h2", I18n.t("instance_admin.index.users")
    assert_select "[data-testid=instance-admin-user-#{admin.id}]" do
      assert_select "p", text: admin.display_label
      assert_select "p", text: admin.email_address
      assert_select "span", text: I18n.t("instance_admin.index.instance_admin_badge")
      assert_select "span", text: I18n.t("instance_admin.index.workspace_count", count: admin.memberships.count)
    end
    assert_select "[data-testid=instance-admin-user-#{member.id}]" do
      assert_select "p", text: member.display_label
      assert_select "p", text: member.email_address
      assert_select "span", text: I18n.t("instance_admin.index.user_badge")
      assert_select "span", text: I18n.t("instance_admin.index.workspace_count", count: member.memberships.count)
    end
    assert_select "[data-testid=instance-admin-users] a", count: 0
    assert_select "[data-testid=instance-admin-users] form", count: 0
  end
end
