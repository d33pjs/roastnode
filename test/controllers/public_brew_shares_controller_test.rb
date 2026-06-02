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

  test "viewer cannot manage public shares" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_brew_public_brew_share_path(brews(:morning_espresso))

    assert_redirected_to root_path
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

    def create_share_for(brew, user:, enabled: true, password: nil)
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title: "Shared shot",
        password:,
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
