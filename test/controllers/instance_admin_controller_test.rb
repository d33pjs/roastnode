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
end
