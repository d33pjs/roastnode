require "application_system_test_case"

class BrewDraftGrinderReminderTest < ApplicationSystemTestCase
  test "an already open phone form refreshes household grinder changes without replacing its draft" do
    brews(:morning_espresso).update!(grind_setting: "1/1,00", occurred_at: 1.day.ago)
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    wait_for_stimulus("brew-grinder-reminder")
    fill_in "Grind setting", with: "1/1,00"
    fill_in "Bean in (g)", with: "18"
    assert_selector "[data-testid=brew-grinder-reminder][data-setting-match=true]"

    workspaces(:household).brews.create!(user: users(:two), bean: beans(:open_household),
      grinder: equipment(:household_grinder), method: "espresso", bean_weight_grams: 1,
      grind_setting: "1/3,0", occurred_at: Time.current)
    execute_script("window.dispatchEvent(new Event('focus'))")

    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "1/3,0"
    assert_selector "[data-testid=brew-grinder-reminder][data-setting-match=false]", text: "Check grinder setting"
    assert_selector "input[data-physical-check=true]"
    assert_equal "1/1,00", find('input[name="brew[grind_setting]"]').value
    assert_equal "18", find('input[name="brew[bean_weight_grams]"]').value
    find("[data-testid=brew-grind-setting-apply]").click
    assert_selector "[data-testid=brew-grinder-reminder][data-setting-match=true]"
    assert_equal "1/3,0", find('input[name="brew[grind_setting]"]').value
    assert_no_selector "input[data-physical-check=true]"
  end

  test "browser back refreshes history after a newer brew was logged while away" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    wait_for_stimulus("brew-grinder-reminder")
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "12"
    find("a[href='#{dashboard_path}']", match: :first).click
    assert_current_path dashboard_path
    workspaces(:household).brews.create!(user: users(:one), bean: beans(:open_household),
      grinder: equipment(:household_grinder), method: "espresso", bean_weight_grams: 1,
      occurred_at: Time.current, grind_setting: "fresh 14")

    page.go_back

    assert_current_path new_brew_path(method: "espresso")
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "fresh 14"
    assert_equal "fresh 14", find('input[name="brew[grind_setting]"]').value
  end

  test "returning to the log after each of a new bag's first three brews shows fresh history" do
    source = beans(:open_household)
    duplicate = source.duplicate_for_new_bag!
    duplicate.update!(opened_on: Date.current)
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    wait_for_stimulus("brew-grinder-reminder")
    find("label[for='brew_bean_id_#{duplicate.id}']").click

    %w[1/0,25 1/0,50 1/0,75].each do |setting|
      fill_in "Grind setting", with: setting
      fill_in "Bean in (g)", with: "1"
      click_button "Save brew"
      assert_current_path %r{\A/brews/\d+\z}
      page.go_back
      assert_current_path new_brew_path(method: "espresso")
      wait_for_stimulus("brew-grinder-reminder")
      assert_selector "#brew_bean_id_#{duplicate.id}:checked"
      assert_selector "[data-brew-grinder-reminder-target=latest]", text: setting
      assert_no_selector "[data-testid=brew-grinder-reminder][data-adjustment-needed=true]"
      assert_no_selector "[data-brew-grinder-reminder-target=inherited]:not([hidden])"
      assert_equal setting, find('input[name="brew[grind_setting]"]').value
      assert_equal "", find('input[name="brew[bean_weight_grams]"]').value
    end
  end

  test "Espresso can apply a differing selected-bean grind setting explicitly" do
    selected_bean = beans(:second_open_household)
    selected_bean.update!(grind_state: "whole_bean")
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
    assert_no_selector "[data-testid=brew-grinder-reminder][data-adjustment-needed=true]"

    find("label[for='brew_bean_id_#{selected_bean.id}']").click

    assert_selector "#brew_bean_id_#{selected_bean.id}:checked"
    assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"
    assert_selector "[data-testid=brew-grinder-reminder][data-adjustment-needed=true]", text: "Check grinder setting"

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    find("[data-testid=brew-grinder-reminder]").scroll_to(:top)
    assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-adjustment-mobile-light.png"))
    execute_script("document.documentElement.className = 'theme-dark'")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-adjustment-mobile-dark.png"))
    execute_script("document.documentElement.className = 'theme-light'")
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")

    fill_in "Grind setting", with: " 1/1,50 "
    assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"
    assert_selector "[data-testid=brew-grinder-reminder][data-setting-match=true]", text: "Setting matches"
    assert_selector "input[data-physical-check=true]"

    fill_in "Grind setting", with: "manual 9"
    assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"
    find("[data-testid=brew-grind-setting-apply]").click

    assert_equal "1/1,50", grind_input.value
    assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value
    assert_selector "[data-testid=brew-grinder-reminder][data-adjustment-needed=true][data-setting-match=true]", text: "Setting matches"
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    execute_script("document.querySelector('input[name=\"brew[grind_setting]\"]').scrollIntoView({block: 'center'})")
    assert_selector "[data-brew-grinder-reminder-target=fieldReminder]:not([hidden])", text: "Double-check grinder"
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-field-reminder-mobile.png"))
    fill_in "Grind setting", with: "A long grinder setting that needs all the available space", fill_options: { rapid: false }
    assert_equal "A long grinder setting that needs all the available space", grind_input.value
    assert_no_selector "[data-brew-grinder-reminder-target=fieldReminder]:not([hidden])"
    assert_selector "input[data-physical-check=true]"
    assert_equal true, evaluate_script("getComputedStyle(document.querySelector('input[data-physical-check=true]')).borderColor === getComputedStyle(document.querySelector('[data-brew-grinder-reminder-target=fieldReminder]')).color")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-long-field-mobile.png"))
    fill_in "Grind setting", with: "1/1,50"
    assert_selector "[data-brew-grinder-reminder-target=fieldReminder]:not([hidden])"
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    assert_draft_field storage_key, "brew[grind_setting]", "1/1,50"
  end

  test "restore and discard synchronize the bean warning without changing grinder inputs" do
    beans(:second_open_household).update!(grind_state: "whole_bean")
    sign_in_through_browser
    visit new_brew_path(method: "espresso")

    default_bean = beans(:open_household)
    draft_bean = beans(:second_open_household)
    grind_setting = find('input[name="brew[grind_setting]"]').value
    grinder_id = find('input[name="brew[grinder_id]"]:checked').value
    storage_key = find("form[data-brew-draft-storage-key-value]")["data-brew-draft-storage-key-value"]

    wait_for_stimulus("brew-draft")
    assert_no_selector "#brew_bean_id_#{draft_bean.id}:checked"
    find("label[for='brew_bean_id_#{draft_bean.id}']").click
    assert_selector "#brew_bean_id_#{draft_bean.id}:checked"
    assert_draft_field storage_key, "brew[bean_id]", draft_bean.id.to_s

    visit new_brew_path(method: "espresso")

    assert_selector "#brew_bean_id_#{draft_bean.id}:checked"
    assert_selector "[data-testid=brew-grinder-reminder]:not([hidden])", text: "Grinder history"
    within "[data-testid=brew-grinder-reminder]" do
      assert_text "Previous brew"
      assert_text default_bean.display_name
      assert_text "No settings recorded for this coffee on this grinder yet."
    end
    assert_equal grind_setting, find('input[name="brew[grind_setting]"]').value
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value

    click_button "Discard"

    assert_selector "#brew_bean_id_#{default_bean.id}:checked"
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "12"
    assert_no_text "No settings recorded for this coffee on this grinder yet."
    assert_equal grind_setting, find('input[name="brew[grind_setting]"]').value
    assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value
  end

  test "closed actual last bean renders historical status and truthful initial warning" do
    closed_bean = beans(:open_household)
    selected_bean = beans(:second_open_household)
    selected_bean.update!(grind_state: "whole_bean")
    closed_bean.update!(remaining_grams: 0, archived_at: Time.current)
    brews(:morning_espresso).update!(occurred_at: 1.minute.ago, grind_setting: "truthful 12")
    sign_in_through_browser

    visit new_brew_path(method: "espresso")

    assert_no_selector "#brew_bean_id_#{closed_bean.id}"
    assert_selector "#brew_bean_id_#{selected_bean.id}:checked"
    assert_no_selector "[data-testid^=brew-bean-last-used-]"
    assert_selector "[data-testid=brew-bean-historical-last-used]", count: 1,
      text: "✓ Last used: #{closed_bean.display_name} · no longer open"
    assert_selector "[data-testid=brew-grinder-reminder]:not([hidden])", text: "Grinder history"
    within "[data-testid=brew-grinder-reminder]" do
      assert_text closed_bean.display_name
      assert_text "truthful 12"
      assert_text "No settings recorded for this coffee on this grinder yet."
    end
  end

  test "shared history stays visible across copy and grinder changes at mobile widths" do
    source = beans(:open_household)
    source.update!(name: "A very long coffee name from a small farm with a particularly long harvest description")
    brews(:morning_espresso).update!(occurred_at: 6.days.ago)
    %w[6 6 6 7 7 8 8 9].each_with_index do |setting, index|
      workspaces(:household).brews.create!(user: users(:one), bean: source,
        grinder: equipment(:household_grinder), method: "espresso", bean_weight_grams: 1,
        occurred_at: 5.days.ago + index.hours, grind_setting: setting)
    end
    duplicate = source.duplicate_for_new_bag!
    duplicate.update!(opened_on: Date.current)
    other_grinder = workspaces(:household).equipment.create!(name: "Other household grinder", kind: "grinder")
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    wait_for_stimulus("brew-grinder-reminder")
    wait_for_stimulus("brew-draft")
    find("label[for='brew_bean_id_#{duplicate.id}']").click
    assert_selector "#brew_bean_id_#{duplicate.id}:checked"
    fill_in "Grind setting", with: "manual"
    within "[data-testid=brew-grinder-reminder]" do
      assert_text "From a previous bag of this coffee"
      assert_selector "[data-brew-grinder-reminder-target=latest]", text: "9"
      assert_selector "[data-brew-grinder-reminder-target=rows] li", count: 3
      assert_selector "[data-brew-grinder-reminder-target=rows] li", text: "9"
    end
    select "Most used", from: "Settings"
    assert_no_selector "[data-brew-grinder-reminder-target=rows] li", text: "9"
    select "Best rated", from: "Settings"
    assert_selector "[data-brew-grinder-reminder-target=rows] li", count: 1, text: /12.*4\/5.*1 rated/m
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "9"
    assert_equal "manual", find('input[name="brew[grind_setting]"]').value
    select "Most used", from: "Settings"
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-desktop-light.png"))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    find("[data-testid=brew-grinder-reminder]").scroll_to(:top)
    assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-mobile-light.png"))
    execute_script("document.documentElement.className = 'theme-dark'")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-mobile-dark.png"))
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-desktop-dark.png"))
    find("[data-testid=brew-grind-setting-apply]").click
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "9"
    assert_selector "[data-brew-grinder-reminder-target=rows] li", count: 3
    find("label[for=brew_grinder_id_#{other_grinder.id}]").click
    assert_text "No settings recorded for this coffee on this grinder yet."
    assert_no_selector "[data-brew-grinder-reminder-target=history]:not([hidden])"
    assert_equal "9", find('input[name="brew[grind_setting]"]').value
    find("label[for=brew_grinder_id_none]").click
    assert_text "Select a grinder to see its history.", count: 1
    find("label[for=brew_grinder_id_#{equipment(:household_grinder).id}]").click
    assert_selector "[data-brew-grinder-reminder-target=latest]", text: "9"
  end

  test "coffee history offers explicit matching choices after roaster selection" do
    source = beans(:open_household)
    source.update!(name: "A long coffee name whose matching history details must remain readable on mobile")
    source.duplicate_for_new_bag!
    sign_in_through_browser
    visit new_bean_path
    wait_for_stimulus("coffee-history-choice")
    fill_in "bean_name", with: source.name
    fill_in "bean_roaster_name", with: source.roaster_name[0, 3]
    find("[data-roaster-suggestions-target=list] button", text: source.roaster_name, exact_text: true).click
    assert_selector "#bean_coffee_history_choice option[value='#{source.coffee_history_id}']", text: "2 bags", visible: :all
    assert_equal "", find("#bean_coffee_history_choice").value
    option_label = find("#bean_coffee_history_choice option[value='#{source.coffee_history_id}']", visible: :all).text(:all)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    select option_label, from: "bean_coffee_history_choice"
    assert_selector "#coffee-history-details", text: option_label
    assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    find("#coffee-history-details").scroll_to(:center)
    page.save_screenshot(Rails.root.join("tmp/screenshots/grinder-history-choice-mobile.png"))
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    assert_equal source.coffee_history_id.to_s, find("#bean_coffee_history_choice").value
    fill_in "bean_name", with: "Changed coffee"
    assert_selector "#coffee-history-details", text: option_label
    assert_equal source.coffee_history_id.to_s, find("#bean_coffee_history_choice").value
  end

  test "Hero tools stay on one bounded row and link to complete private and public lists" do
    sign_in_through_browser
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    %w[espresso quick_drip].each do |method|
      tools = 12.times.map do |index|
        workspaces(:household).preparation_tools.create!(name: "A particularly long preparation tool name #{method} #{index}",
          brew_method: method, active: true, position: index)
      end
      brew = workspaces(:household).brews.create!(user: users(:one), bean: beans(:open_household),
        grinder: equipment(:household_grinder), machine: (equipment(:household_machine) if method == "espresso"),
        brewer: (equipment(:household_brewer) if method == "quick_drip"), machine_cups: (2 if method == "quick_drip"),
        method:, occurred_at: Time.current, bean_weight_grams: 1)
      brew.snapshot_preparation_tools!(tools)

      visit brew_path(brew)
      assert_selector "[data-testid=brew-hero-tools] [data-testid=brew-tool]", count: 2
      assert_selector "[data-testid=brew-tools-more]", text: "+ 10 more"
      assert_selector "#brew-tools [data-testid=brew-detail-tool]", count: 12
      assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      assert_operator find("[data-testid=brew-hero-tools]").rect.height, :<, 40
      execute_script("document.querySelector('[data-testid=brew-hero-card]').scrollIntoView({block: 'start'})")
      page.save_screenshot(Rails.root.join("tmp/screenshots/hero-tools-#{method}-mobile.png"))
      find("[data-testid=brew-tools-more]").click
      assert_current_path brew_path(brew)
      assert_equal "#brew-tools", evaluate_script("window.location.hash")

      next unless method == "espresso"

      share = brew.create_public_brew_share!(workspace: brew.workspace, created_by: brew.user, updated_by: brew.user,
        enabled: true, title: "Shared shot", snapshot: PublicBrewShareSnapshotBuilder.new(brew:, title: "Shared shot", selected_photo_attachment_ids: []).call)
      visit public_brew_page_path(share.token)
      assert_selector "[data-testid=public-brew-hero-tools] [data-testid=public-gear-anchor]", count: 2
      assert_selector "[data-testid=public-brew-tools-more]", text: "+ 10 more"
      assert_selector "#public-brew-tools [data-kind=tool]", count: 12
      assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      page.save_screenshot(Rails.root.join("tmp/screenshots/hero-tools-public-mobile.png"))
      find("[data-testid=public-brew-tools-more]").click
      assert_current_path public_brew_page_path(share.token)
      assert_equal "#public-brew-tools", evaluate_script("window.location.hash")
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def wait_for_stimulus(identifier)
      page.document.synchronize(errors: [ Capybara::ExpectationNotMet ]) do
        connected = evaluate_script(<<~JAVASCRIPT, identifier)
          document.fonts.status === "loaded" && window.Stimulus.controllers.some((controller) => controller.identifier === arguments[0])
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
      evaluate_async_script("document.fonts.ready.then(arguments[0])")
      fill_in "Email", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
