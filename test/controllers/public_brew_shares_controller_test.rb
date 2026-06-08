require "test_helper"

class PublicBrewSharesControllerTest < ActionDispatch::IntegrationTest
  test "writer can open new share form for own brew" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    brew_photo = attach_photo(brew)
    bean_photo = attach_photo(brew.bean)
    grinder_photo = attach_photo(brew.grinder)
    machine_photo = attach_photo(brew.machine)
    tool_photo = attach_photo(preparation_tools(:wdt))
    brew.snapshot_preparation_tools!([ preparation_tools(:wdt) ])
    sign_in_as(user)

    get new_brew_public_brew_share_path(brew)

    assert_response :success
    assert_select "h1", I18n.t("public_brew_shares.new.title")
    assert_select "input[type=checkbox][name=?]", "public_brew_share[enabled]"
    assert_select "input[name=?]", "public_brew_share[title]"
    assert_select "input[name=?][value=?]", "public_brew_share[title]", "Espresso with #{brew.bean.name}"
    assert_select "input[name=?][value*=?]", "public_brew_share[title]", brew.bean.roaster_name, count: 0
    assert_select "input[type=password][name=?]", "public_brew_share[password]"
    [ brew_photo, bean_photo, grinder_photo, machine_photo, tool_photo ].each do |photo|
      assert_select "input[type=checkbox][name=?][value=?]", "public_brew_share[selected_photo_attachment_ids][]", photo.id.to_s
    end
  end

  test "writer creates disabled password protected share snapshot for own brew" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user, public_note: "Public tasting note.")
    photo = attach_photo(brew)
    sign_in_as(user)

    assert_difference -> { PublicBrewShare.count }, 1 do
      post brew_public_brew_share_path(brew), params: {
        public_brew_share: {
          enabled: "0",
          title: "Shared morning shot",
          password: "espresso",
          selected_photo_attachment_ids: [ photo.id ]
        }
      }
    end

    share = brew.reload.public_brew_share
    assert_redirected_to edit_brew_public_brew_share_path(brew)
    assert_equal "Shared morning shot", share.title
    assert_not share.enabled?
    assert share.password_protected?
    assert_equal [ photo.id ], share.selected_photo_attachment_ids
    assert_equal user, share.created_by
    assert_equal user, share.updated_by
    assert_equal "Public tasting note.", share.snapshot.dig("brew", "public_note")
  end

  test "create filters selected photos to share records" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    selected_photo = attach_photo(brew)
    unrelated_photo = attach_photo(beans(:other_workspace_open))
    sign_in_as(user)

    post brew_public_brew_share_path(brew), params: {
      public_brew_share: {
        enabled: "0",
        title: "Filtered shot",
        selected_photo_attachment_ids: [ selected_photo.id, unrelated_photo.id ]
      }
    }

    share = brew.reload.public_brew_share
    assert_equal [ selected_photo.id ], share.selected_photo_attachment_ids
    assert_includes share.public_attachment_ids, selected_photo.id
    assert_not_includes share.public_attachment_ids, unrelated_photo.id
  end

  test "post to existing share updates without creating duplicate" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    share = create_share_for(brew, user:, title: "Old share")
    sign_in_as(user)

    assert_no_difference -> { PublicBrewShare.count } do
      post brew_public_brew_share_path(brew), params: {
        public_brew_share: {
          enabled: "1",
          title: "Updated by post",
          selected_photo_attachment_ids: []
        }
      }
    end

    assert_equal share.id, brew.reload.public_brew_share.id
    assert_equal "Updated by post", share.reload.title
    assert share.enabled?
  end

  test "writer cannot manage another writers brew share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    create_share_for(brews(:morning_espresso), user: users(:one))
    sign_in_as(user)

    get edit_brew_public_brew_share_path(brews(:morning_espresso))

    assert_redirected_to root_path
  end

  test "owner can manage another users brew share" do
    writer = users(:two)
    writer.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(writer)
    share = create_share_for(brew, user: writer)
    sign_in_as(users(:one))

    get edit_brew_public_brew_share_path(brew)

    assert_response :success
    assert_select "h1", I18n.t("public_brew_shares.edit.title")
    assert_select "input[name=?][value=?]", "public_brew_share[title]", share.title
  end

  test "edit shows enabled public URL and remove action" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    share = create_share_for(brew, user:, enabled: true)
    sign_in_as(user)

    get edit_brew_public_brew_share_path(brew)

    assert_response :success
    assert_select "[data-testid=public-brew-share-url] a[href=?]", public_brew_page_path(share.token), text: public_brew_page_url(share.token)
    assert_select "form[data-testid=public-brew-share-destroy-form][action=?]", brew_public_brew_share_path(brew)
    assert_select "form[data-testid=public-brew-share-destroy-form] input[name=_method][value=delete]"
    assert_select "button", text: I18n.t("public_brew_shares.edit.remove")
    assert_select "[data-turbo-confirm=?]", I18n.t("public_brew_shares.edit.remove_confirmation")
  end

  test "viewer cannot manage public shares" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_brew_public_brew_share_path(brews(:morning_espresso))

    assert_redirected_to root_path
  end

  test "new redirects quick drip brews because public sharing is espresso only" do
    user = users(:one)
    brew = create_quick_drip_brew_for(user)
    sign_in_as(user)

    get new_brew_public_brew_share_path(brew)

    assert_redirected_to brew_path(brew)
    assert_equal I18n.t("public_brew_shares.unsupported_method"), flash[:alert]
  end

  test "create redirects quick drip brews because public sharing is espresso only" do
    user = users(:one)
    brew = create_quick_drip_brew_for(user)
    sign_in_as(user)

    assert_no_difference -> { PublicBrewShare.count } do
      post brew_public_brew_share_path(brew), params: {
        public_brew_share: {
          enabled: "1",
          title: "Shared batch",
          selected_photo_attachment_ids: []
        }
      }
    end

    assert_redirected_to brew_path(brew)
    assert_equal I18n.t("public_brew_shares.unsupported_method"), flash[:alert]
  end

  test "edit redirects existing quick drip shares because public sharing is espresso only" do
    user = users(:one)
    brew = create_quick_drip_brew_for(user)
    create_share_for(brew, user:)
    sign_in_as(user)

    get edit_brew_public_brew_share_path(brew)

    assert_redirected_to brew_path(brew)
    assert_equal I18n.t("public_brew_shares.unsupported_method"), flash[:alert]
  end

  test "update can enable share and clear password" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    share = create_share_for(brew, user:, enabled: false, password: "espresso")
    assert share.password_protected?
    sign_in_as(user)

    patch brew_public_brew_share_path(brew), params: {
      public_brew_share: {
        enabled: "1",
        title: "Enabled shot",
        password: "",
        clear_password: "1",
        selected_photo_attachment_ids: []
      }
    }

    assert_redirected_to edit_brew_public_brew_share_path(brew)
    share.reload
    assert share.enabled?
    assert_equal "Enabled shot", share.title
    assert_not share.password_protected?
    assert_equal user, share.updated_by
  end

  test "update redirects existing quick drip shares because public sharing is espresso only" do
    user = users(:one)
    brew = create_quick_drip_brew_for(user)
    share = create_share_for(brew, user:, title: "Old batch")
    sign_in_as(user)

    patch brew_public_brew_share_path(brew), params: {
      public_brew_share: {
        enabled: "1",
        title: "Updated batch",
        selected_photo_attachment_ids: []
      }
    }

    assert_redirected_to brew_path(brew)
    assert_equal I18n.t("public_brew_shares.unsupported_method"), flash[:alert]
    assert_equal "Old batch", share.reload.title
  end

  test "blank password keeps existing password" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    share = create_share_for(brew, user:, enabled: true, password: "espresso")
    sign_in_as(user)

    patch brew_public_brew_share_path(brew), params: {
      public_brew_share: {
        enabled: "1",
        title: "Still protected",
        password: "",
        selected_photo_attachment_ids: []
      }
    }

    assert_redirected_to edit_brew_public_brew_share_path(brew)
    share.reload
    assert share.password_protected?
    assert share.authenticate_password("espresso")
    assert_equal "Still protected", share.title
  end

  test "writer can destroy own public share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(user)
    create_share_for(brew, user:)
    sign_in_as(user)

    assert_difference -> { PublicBrewShare.count }, -1 do
      delete brew_public_brew_share_path(brew)
    end

    assert_redirected_to brew_path(brew)
  end

  test "owner can destroy public share from workspace settings and return there" do
    writer = users(:two)
    writer.update!(active_workspace: workspaces(:household))
    brew = create_brew_for(writer)
    share = create_share_for(brew, user: writer, enabled: true)
    sign_in_as(users(:one))

    assert_difference -> { PublicBrewShare.count }, -1 do
      delete brew_public_brew_share_path(brew), params: { return_to: "workspace" }
    end

    assert_redirected_to edit_workspace_path(anchor: "public-shares")
    assert_not PublicBrewShare.exists?(share.id)
  end

  test "writer cannot destroy another writers public share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    create_share_for(brews(:morning_espresso), user: users(:one))
    sign_in_as(user)

    assert_no_difference -> { PublicBrewShare.count } do
      delete brew_public_brew_share_path(brews(:morning_espresso))
    end

    assert_redirected_to root_path
  end

  test "viewer cannot destroy public share" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    create_share_for(brews(:morning_espresso), user: users(:one))
    sign_in_as(user)

    assert_no_difference -> { PublicBrewShare.count } do
      delete brew_public_brew_share_path(brews(:morning_espresso))
    end

    assert_redirected_to root_path
  end

  private
    def create_brew_for(user, public_note: nil)
      workspaces(:household).brews.create!(
        user:,
        bean: beans(:second_open_household),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0),
        bean_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 42,
        taste_balance: "neutral",
        public_note:
      )
    end

    def create_quick_drip_brew_for(user)
      workspaces(:household).brews.create!(
        user:,
        method: "quick_drip",
        bean: beans(:second_open_household),
        brewer: equipment(:household_brewer),
        machine_cups: 6,
        coffee_spoons: 6,
        taste_balance: "neutral"
      )
    end

    def create_share_for(brew, user:, enabled: true, password: nil, title: "Shared shot")
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title:,
        password:,
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title:,
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
