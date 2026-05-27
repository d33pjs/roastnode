require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  test "owner can edit active workspace settings" do
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "h1", I18n.t("workspaces.edit.title")
    assert_select "input[name=?][value=?]", "workspace[name]", workspaces(:household).name
    assert_select "input[name=?][value=?]", "workspace[default_currency]", "EUR"
    assert_select "input[type=file][name=?]", "workspace[logo]"
    assert_select "input[type=file][name=?]", "workspace[banner]"
    assert_select "a[data-testid=back-link][href=?]", dashboard_path
  end

  test "workspace edit previews existing identity media" do
    workspace = workspaces(:household)
    logo = attach_named_photo(workspace, :logo, filename: "workspace-logo.jpg")
    banner = attach_named_photo(workspace, :banner, filename: "workspace-banner.jpg")
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "img[data-testid=workspace-logo-preview][src=?]", media_attachment_path(logo, variant: :thumbnail)
    assert_select "img[data-testid=workspace-banner-preview][src=?]", media_attachment_path(banner, variant: :thumbnail)
  end

  test "owner can update active workspace name and default currency" do
    sign_in_as(users(:one))

    patch workspace_path, params: {
      workspace: {
        name: "Jens Coffee Lab",
        default_currency: "eur"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal "Jens Coffee Lab", workspaces(:household).reload.name
    assert_equal "EUR", workspaces(:household).default_currency
  end

  test "owner can update workspace identity media" do
    workspace = workspaces(:household)
    sign_in_as(users(:one))

    patch workspace_path, params: {
      workspace: {
        name: workspace.name,
        default_currency: workspace.default_currency,
        logo: photo_upload(filename: "logo.jpg"),
        banner: photo_upload(filename: "banner.jpg")
      }
    }

    assert_redirected_to dashboard_path
    assert workspace.reload.logo.attached?
    assert workspace.banner.attached?
  end

  test "admin can update active workspace settings" do
    admin = User.create!(email_address: "workspace-admin@example.com", password: "password")
    Membership.create!(workspace: workspaces(:household), user: admin, role: "admin")
    admin.update!(active_workspace: workspaces(:household))
    sign_in_as(admin)

    patch workspace_path, params: {
      workspace: {
        name: "Shared Coffee Home",
        default_currency: "CHF"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal "Shared Coffee Home", workspaces(:household).reload.name
    assert_equal "CHF", workspaces(:household).default_currency
  end

  test "member cannot edit active workspace settings" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get edit_workspace_path

    assert_redirected_to root_path
  end

  test "invalid workspace settings re-render edit form" do
    sign_in_as(users(:one))

    patch workspace_path, params: { workspace: { name: "", default_currency: "" } }

    assert_response :unprocessable_entity
    assert_select "input[name=?]", "workspace[name]"
  end

  test "user can switch to workspace they belong to" do
    user = users(:two)
    sign_in_as(user)

    patch switch_workspace_path(workspaces(:other_household))

    assert_redirected_to root_path
    assert_equal workspaces(:other_household), user.reload.active_workspace
  end

  test "user cannot switch to workspace they do not belong to" do
    user = users(:one)
    sign_in_as(user)

    patch switch_workspace_path(workspaces(:other_household))

    assert_redirected_to root_path
    assert_not_equal workspaces(:other_household), user.reload.active_workspace
  end
end
