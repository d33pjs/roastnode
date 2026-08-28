require "application_system_test_case"

class BrewDraftGrinderReminderTest < ApplicationSystemTestCase
  test "Espresso can apply a differing selected-bean grind setting explicitly" do
    selected_bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    workspaces(:household).brews.create!(
      user: users(:one),
      bean: selected_bean,
      grinder:,
      machine: equipment(:household_machine),
      method: "espresso",
      occurred_at: 1.day.ago,
      bean_weight_grams: 1,
      grind_setting: "1/1,50",
      rating: 5
    )
    brews(:morning_espresso).update!(occurred_at: 1.minute.ago, grind_setting: "1/1,75", rating: 5)
    sign_in_through_browser

    visit new_brew_path(method: "espresso")
    wait_for_stimulus("brew-grinder-reminder")
    wait_for_stimulus("brew-draft")

    grind_input = find('input[name="brew[grind_setting]"]')
    grinder_id = find('input[name="brew[grinder_id]"]:checked').value
    storage_key = find("form[data-brew-draft-storage-key-value]")["data-brew-draft-storage-key-value"]

    assert_equal "1/1,75", grind_input.value
    assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"

    choose("brew_bean_id_#{selected_bean.id}")

    assert_selector "#brew_bean_id_#{selected_bean.id}:checked"
    assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"

    fill_in "Grind setting", with: " 1/1,50 "
    assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"

    fill_in "Grind setting", with: "manual 9"
    assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"
    find("[data-testid=brew-grind-setting-apply]").click

    assert_equal "1/1,50", grind_input.value
    assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value
    assert_draft_field storage_key, "brew[grind_setting]", "1/1,50"
  end

  test "restore and discard synchronize the bean warning without changing grinder inputs" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")

    default_bean = beans(:open_household)
    draft_bean = beans(:second_open_household)
    grind_setting = find('input[name="brew[grind_setting]"]').value
    grinder_id = find('input[name="brew[grinder_id]"]:checked').value
    storage_key = find("form[data-brew-draft-storage-key-value]")["data-brew-draft-storage-key-value"]

    wait_for_stimulus("brew-draft")
    assert_no_selector "#brew_bean_id_#{draft_bean.id}:checked"
    find("#brew_bean_id_#{draft_bean.id}").click
    assert_selector "#brew_bean_id_#{draft_bean.id}:checked"
    assert_draft_field storage_key, "brew[bean_id]", draft_bean.id.to_s

    visit new_brew_path(method: "espresso")

    assert_selector "#brew_bean_id_#{draft_bean.id}:checked"
    assert_selector "[data-testid=brew-grinder-reminder]:not([hidden])", text: "Check grinder settings"
    within "[data-testid=brew-grinder-reminder]" do
      assert_text "Previous brew"
      assert_text default_bean.display_name
      assert_text "No rated grinder reference yet"
    end
    assert_equal grind_setting, find('input[name="brew[grind_setting]"]').value
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value

    click_button "Discard"

    assert_selector "#brew_bean_id_#{default_bean.id}:checked"
    assert_no_selector "[data-testid=brew-grinder-reminder]:not([hidden])"
    assert_no_text "No rated grinder reference yet"
    assert_equal grind_setting, find('input[name="brew[grind_setting]"]').value
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value
  end

  test "closed actual last bean renders historical status and truthful initial warning" do
    closed_bean = beans(:open_household)
    selected_bean = beans(:second_open_household)
    closed_bean.update!(remaining_grams: 0, archived_at: Time.current)
    brews(:morning_espresso).update!(occurred_at: 1.minute.ago, grind_setting: "truthful 12")
    sign_in_through_browser

    visit new_brew_path(method: "espresso")

    assert_no_selector "#brew_bean_id_#{closed_bean.id}"
    assert_selector "#brew_bean_id_#{selected_bean.id}:checked"
    assert_no_selector "[data-testid^=brew-bean-last-used-]"
    assert_selector "[data-testid=brew-bean-historical-last-used]", count: 1,
      text: "✓ Last used: #{closed_bean.display_name} · no longer open"
    assert_selector "[data-testid=brew-grinder-reminder]:not([hidden])", text: "Check grinder settings"
    within "[data-testid=brew-grinder-reminder]" do
      assert_text closed_bean.display_name
      assert_text "truthful 12"
      assert_text "No rated grinder reference yet"
    end
  end

  private
    def wait_for_stimulus(identifier)
      page.document.synchronize(errors: [ Capybara::ExpectationNotMet ]) do
        connected = evaluate_script(<<~JAVASCRIPT, identifier)
          window.Stimulus.controllers.some((controller) => controller.identifier === arguments[0])
        JAVASCRIPT
        raise Capybara::ExpectationNotMet, "#{identifier} did not connect" unless connected
      end
    end

    def assert_draft_field(storage_key, field_name, expected_value)
      page.document.synchronize(errors: [ Capybara::ExpectationNotMet ]) do
        actual_value = evaluate_script(<<~JAVASCRIPT, storage_key, field_name)
          JSON.parse(localStorage.getItem(arguments[0]) || "{}").fields?.[arguments[1]]
        JAVASCRIPT
        raise Capybara::ExpectationNotMet, "expected stored #{field_name} to be #{expected_value.inspect}, got #{actual_value.inspect}" unless actual_value == expected_value
      end
    end

    def sign_in_through_browser
      visit new_session_path
      fill_in "Email", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
