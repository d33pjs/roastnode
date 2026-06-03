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

  test "owner sees public share management with full ip view log" do
    share = create_public_brew_share_for(brews(:morning_espresso), enabled: true)
    share.public_brew_share_views.create!(
      ip_address: "198.51.100.31",
      user_agent: "Settings test browser",
      viewed_at: Time.zone.local(2026, 6, 3, 11, 0, 0)
    )
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "[data-testid=workspace-public-shares]"
    assert_select "[data-testid=?]", "workspace-public-share-#{share.id}", text: /Shared shot/
    assert_select "a[href=?]", public_brew_page_path(share.token), text: public_brew_page_url(share.token)
    assert_select "a[href=?]", edit_brew_public_brew_share_path(share.brew)
    assert_select "form[action=?]", brew_public_brew_share_path(share.brew)
    assert_select "[data-testid=?]", "public-share-view-count-#{share.id}", text: "1"
    assert_select "[data-testid=?]", "public-share-recent-ip-#{share.id}", text: /198\.51\.100\.31/
  end

  test "workspace public share management excludes other workspaces" do
    other_share = create_public_brew_share_for(brews(:other_workspace_brew), enabled: true, user: users(:two))
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "[data-testid=?]", "workspace-public-share-#{other_share.id}", count: 0
  end

  test "member cannot see public share management full ip data" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    create_public_brew_share_for(brews(:morning_espresso), enabled: true)
    sign_in_as(user)

    get edit_workspace_path

    assert_redirected_to root_path
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

  test "owner can transfer ownership to another member" do
    sign_in_as(users(:one))

    patch transfer_ownership_workspace_path, params: { membership_id: memberships(:member).id }

    assert_redirected_to memberships_path
    assert_equal "admin", memberships(:owner).reload.role
    assert_equal "owner", memberships(:member).reload.role
  end

  test "admin cannot transfer ownership" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "transfer-admin@example.com", password: "password")
    admin_membership = Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    patch transfer_ownership_workspace_path, params: { membership_id: memberships(:member).id }

    assert_redirected_to root_path
    assert_equal "admin", admin_membership.reload.role
    assert_equal "member", memberships(:member).reload.role
  end

  test "owner can delete active workspace with exact confirmation" do
    workspace = workspaces(:household)
    users(:one).update!(active_workspace: workspace)
    users(:two).update!(active_workspace: workspace)
    bean_id = beans(:open_household).id
    sign_in_as(users(:one))

    delete workspace_path, params: { confirmation: workspace.name }

    assert_redirected_to root_path
    assert_not Workspace.exists?(workspace.id)
    assert_not Bean.exists?(bean_id)
    assert_nil users(:one).reload.active_workspace
    assert_nil users(:two).reload.active_workspace
  end

  test "workspace deletion requires exact confirmation" do
    workspace = workspaces(:household)
    sign_in_as(users(:one))

    delete workspace_path, params: { confirmation: "wrong name" }

    assert_redirected_to edit_workspace_path
    assert Workspace.exists?(workspace.id)
  end

  test "admin cannot delete workspace" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "delete-admin@example.com", password: "password")
    Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    delete workspace_path, params: { confirmation: workspace.name }

    assert_redirected_to root_path
    assert Workspace.exists?(workspace.id)
  end

  test "owner sees workspace deletion danger zone" do
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "form[action=?][method=post]", workspace_path
    assert_select "input[name=_method][value=delete]"
    assert_select "input[name=confirmation]"
  end

  test "admin does not see workspace deletion danger zone" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "danger-admin@example.com", password: "password")
    Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    get edit_workspace_path

    assert_response :success
    assert_select "input[name=confirmation]", count: 0
  end

  private
    def create_public_brew_share_for(brew, enabled:, user: users(:one), title: "Shared shot")
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title:,
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title:,
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
