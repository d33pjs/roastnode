require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can edit display name" do
    user = users(:one)
    sign_in_as(user)

    get edit_profile_path

    assert_response :success
    assert_select "[data-testid=profile-email]", user.email_address
    assert_select "input[name=?]", "user[display_name]"
    assert_select "input[name=?]", "user[email_address]", count: 0
    assert_select "select[name=?]", "user[default_landing_screen]"
    assert_select "select[name=?]", "user[default_brew_focus_field]"
  end

  test "signed-in user can update display name and form preferences" do
    user = users(:one)
    sign_in_as(user)

    patch profile_path, params: {
      user: {
        display_name: "Jens",
        default_landing_screen: "log_espresso",
        default_brew_focus_field: "dose_grams"
      }
    }

    assert_redirected_to root_path
    assert_equal "Jens", user.reload.display_name
    assert_equal "log_espresso", user.default_landing_screen
    assert_equal "dose_grams", user.default_brew_focus_field
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
