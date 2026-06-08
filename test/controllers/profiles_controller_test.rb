require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can edit display name" do
    user = users(:one)
    sign_in_as(user)

    get edit_profile_path

    assert_response :success
    assert_select "[data-testid=profile-email]", user.email_address
    assert_select "[data-testid=profile-workspace-role]", I18n.t("profiles.edit.workspace_role_value", role: memberships(:owner).role.humanize)
    assert_select "input[name=?]", "user[display_name]"
    assert_select "input[name=?]", "user[email_address]", count: 0
    assert_select "input[type=file][name=?]", "user[avatar]"
    assert_select "input[type=file][name=?]", "user[public_banner]"
    assert_select "select[name=?]", "user[default_landing_screen]"
    assert_select "select[name=?]", "user[theme]"
    assert_select "select[name=?]", "user[number_format]"
    assert_select "select[name=?]", "user[time_format]"
    assert_select "select[name=?]", "user[default_brew_focus_field]"
    assert_select "input[type=checkbox][name=?][value=?]", "user[hidden_brew_field_names][]", "notes"
    assert_select "input[type=checkbox][name=?][value=?]", "user[hidden_brew_field_names][]", "photos"
    assert_select "a[href=?]", edit_password_change_path, text: I18n.t("profiles.edit.change_password")
    assert_select "a[data-testid=back-link][href=?]", dashboard_path
  end

  test "profile edit previews existing identity media" do
    user = users(:one)
    avatar = attach_named_photo(user, :avatar, filename: "avatar.jpg")
    banner = attach_named_photo(user, :public_banner, filename: "banner.jpg")
    sign_in_as(user)

    get edit_profile_path

    assert_response :success
    assert_select "img[data-testid=profile-avatar-preview][src=?]", media_attachment_path(avatar, variant: :thumbnail)
    assert_select "img[data-testid=profile-public-banner-preview][src=?]", media_attachment_path(banner, variant: :thumbnail)
  end

  test "profile shows passkey account security controls" do
    sign_in_as(users(:one))

    get edit_profile_path

    assert_response :success
    assert_select "h2", I18n.t("profiles.passkeys.title")
    assert_select "[data-controller=?]", "passkey"
    assert_select "form[action=?]", second_factor_passkey_credentials_path
    assert_select "form[action=?]", passkey_credential_path(passkey_credentials(:one_touch_id))
  end

  test "signed-in user can update display name and form preferences" do
    user = users(:one)
    sign_in_as(user)

    patch profile_path, params: {
      user: {
        display_name: "Jens",
        default_landing_screen: "log_espresso",
        theme: "dark",
        number_format: "dot_decimal",
        time_format: "us_12h_seconds",
        default_brew_focus_field: "dose_grams",
        hidden_brew_field_names: %w[rating channeling photos]
      }
    }

    assert_redirected_to root_path
    assert_equal "Jens", user.reload.display_name
    assert_equal "log_espresso", user.default_landing_screen
    assert_equal "dark", user.theme
    assert_equal "dot_decimal", user.number_format
    assert_equal "us_12h_seconds", user.time_format
    assert_equal "dose_grams", user.default_brew_focus_field
    assert_equal %w[rating channeling photos], user.hidden_brew_field_names
  end

  test "profile renders and saves quick drip preferences" do
    sign_in_as(users(:one))

    get edit_profile_path

    assert_response :success
    assert_select "input[type=checkbox][name=?][value=?]", "user[enabled_brew_methods][]", "quick_drip"
    assert_select "input[type=text][name=?][inputmode=decimal]", "user[grams_per_coffee_spoon]"

    patch profile_path, params: {
      user: {
        display_name: "Jens",
        default_landing_screen: "log_espresso",
        enabled_brew_methods: [ "", "quick_drip" ],
        grams_per_coffee_spoon: "4,5"
      }
    }

    assert_redirected_to root_path
    users(:one).reload
    assert_equal %w[quick_drip], users(:one).enabled_brew_methods
    assert_equal 4.5.to_d, users(:one).grams_per_coffee_spoon
  end

  test "profile rejects disabling all brew methods" do
    sign_in_as(users(:one))

    patch profile_path, params: {
      user: {
        enabled_brew_methods: [ "" ],
        grams_per_coffee_spoon: "5"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".text-red-800", text: /Enabled brew methods must include at least one method/
  end

  test "signed-in user can update identity media" do
    user = users(:one)
    sign_in_as(user)

    patch profile_path, params: {
      user: {
        display_name: "Jens",
        avatar: photo_upload(filename: "avatar.jpg"),
        public_banner: photo_upload(filename: "public-banner.jpg")
      }
    }

    assert_redirected_to root_path
    assert user.reload.avatar.attached?
    assert user.public_banner.attached?
  end

  test "profile does not accept unrelated user attributes" do
    user = users(:one)
    sign_in_as(user)

    assert_no_changes -> { user.reload.email_address } do
      patch profile_path, params: { user: { display_name: "Jens", email_address: "leak@example.com" } }
    end

    assert_redirected_to root_path
    assert_equal "Jens", user.reload.display_name
  end

  test "profile edit re-renders invalid display name" do
    sign_in_as(users(:one))

    patch profile_path, params: { user: { display_name: "a" * 81 } }

    assert_response :unprocessable_entity
    assert_select "input[name=?]", "user[display_name]"
  end
end
