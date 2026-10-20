require "application_system_test_case"

class BrewSessionTest < ApplicationSystemTestCase
  test "two coffees keep exact fields, files and stable identities while switching and restoring" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    assert_selector "[data-testid=brew-session]"
    fill_in "Bean in (g)", with: "18,50"
    fill_in "Grind setting", with: "1/2,50"
    fill_in "Notes", with: "Coffee one"
    attach_file "Photos", Rails.root.join("test/fixtures/files/photo.jpg")
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee]", text: "Coffee 2"
    click_button "Full form"
    fill_in "Bean in (g)", with: "17,25"
    fill_in "Grind setting", with: "1/3,0"
    fill_in "Notes", with: "Coffee two"
    assert_selector "[data-brew-session-target=forms] form", count: 2, visible: :all
    assert_no_button "Prepare next coffee"
    click_button "Coffee 1"
    assert_equal "18,50", find('input[name="brew[bean_weight_grams]"]').value
    assert_equal "1/2,50", find('input[name="brew[grind_setting]"]').value
    assert_equal "Coffee one", find('textarea[name="brew[notes]"]').value
    assert_equal 1, evaluate_script("document.querySelector('[data-brew-session-target=forms] form:not([hidden]) input[type=file]').files.length")
    assert_equal true, evaluate_script("Array.from(document.querySelectorAll('[data-brew-session-target=forms] [id]')).map(e => e.id).every((id, index, ids) => ids.indexOf(id) === index)")
    refresh
    assert_text "Unsaved coffees restored from this browser."
    assert_text "Attach photos again"
    assert_equal "Coffee one", find('textarea[name="brew[notes]"]').value
    click_button "Coffee 2"
    click_button "Full form"
    assert_equal "17,25", find('input[name="brew[bean_weight_grams]"]').value
    assert_equal "Coffee two", find('textarea[name="brew[notes]"]').value
  end

  test "mobile stage controls allow validation-free switching and bounded keyboard navigation" do
    beans(:open_household).update!(name: "An exceptionally long coffee label for a shared household espresso session")
    users(:two).update!(display_name: "Alex with a particularly long household display label")
    sign_in_through_browser
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 1000, deviceScaleFactor: 1, mobile: true)
    visit new_brew_path(method: "espresso")
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 1"
    assert_selector "[data-testid=brew-session-coffee][aria-label*='Myself']", text: "Coffee 1"
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffee-one-mobile.png"))
    find("input[name='brew[recipient_selection]'][value='member:#{users(:two).id}']", visible: :all).find(:xpath, "..").click
    assert_selector "[data-testid=brew-session-coffee][aria-label*='Alex']", text: "Coffee 1"
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    click_button "Full form"
    fill_in "Person name", with: "A particularly long recipient label for a visiting coffee enthusiast"
    click_button "Prepare", exact: true
    assert_selector "[data-testid=brew-session-coffee][aria-label*='visiting coffee enthusiast']", text: "Coffee 2"
    assert_operator find("[data-brew-session-target=toolbar]").rect.height, :<, 155
    assert_operator find("[data-brew-session-target=stage]", match: :first).rect.height, :>=, 44
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-mobile-light.png"))
    execute_script("document.documentElement.className = 'theme-dark'")
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-mobile-dark.png"))
    execute_script("document.documentElement.className = 'theme-light'")
    click_button "Extract", exact: true
    assert_selector "[data-section=extraction]"
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-extract-mobile.png"))
    click_button "Taste", exact: true
    assert_selector "[data-section=taste]"
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-taste-mobile.png"))
    click_button "Coffee 1"
    assert_selector "input[name='brew[bean_weight_grams]']"
    assert_equal false, evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    find("[data-testid=brew-session-coffee]", match: :first).send_keys(:arrow_right)
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    metrics = evaluate_script(<<~JAVASCRIPT)
      ({ width: window.innerWidth,
         overflow: document.documentElement.scrollWidth > window.innerWidth,
         toolbarHeight: document.querySelector('[data-brew-session-target=toolbar]').getBoundingClientRect().height,
         minimumStageHeight: Math.min(...Array.from(document.querySelectorAll('[data-brew-session-target=stage]')).map(button => button.getBoundingClientRect().height)),
         minimumCoffeeHeight: Math.min(...Array.from(document.querySelectorAll('[data-testid=brew-session-coffee]')).map(button => button.getBoundingClientRect().height)) })
    JAVASCRIPT
    FileUtils.mkdir_p(Rails.root.join("tmp/parallel-coffees"))
    File.write(Rails.root.join("tmp/parallel-coffees/mobile-metrics.json"), JSON.pretty_generate(metrics))
    execute_script("window.scrollTo(0, 700)")
    page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-sticky-mobile.png"))
    [ 768, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height: 1000, deviceScaleFactor: 1, mobile: false)
      execute_script("window.scrollTo(0, 0)")
      page.save_screenshot(Rails.root.join("tmp/screenshots/parallel-coffees-#{width}.png"))
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "failed saves retain both coffees and a saved second coffee leaves room for a third" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    fill_in "Bean in (g)", with: "18"
    fill_in "Notes", with: "Finish later"
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    click_button "Full form"
    fill_in "Bean in (g)", with: "-1"
    click_button "Continue to extraction"
    assert_text "Grinding confirmed"
    click_button "Full form"
    click_button "Save brew"
    assert_selector "[data-testid=brew-session-error]", text: /greater|positive|not a number/i
    assert_selector "[data-brew-session-target=forms] form", count: 2, visible: :all
    assert_equal "-1", find('input[name="brew[bean_weight_grams]"]').value
    fill_in "Bean in (g)", with: "17"
    click_button "Save brew"
    assert_selector "[data-testid=brew-session-coffee]", text: "Coffee 1"
    assert_no_selector "[data-testid=brew-session-coffee]", text: "Coffee 2"
    assert_equal "Finish later", find('textarea[name="brew[notes]"]').value
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee]", text: "Coffee 3"
  end

  test "saving two confirmed coffees out of order keeps physical grinder chronology" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    fill_in "Bean in (g)", with: "18"
    fill_in "Grind setting", with: "1/2,50"
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    assert_equal "1/2,50", find('input[name="brew[grind_setting]"]').value
    fill_in "Bean in (g)", with: "17"
    fill_in "Grind setting", with: "1/3,0"
    click_button "Continue to extraction"
    assert_text "Grinding confirmed"
    click_button "Save brew"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 1"
    assert_equal "1/2,50", find('input[name="brew[grind_setting]"]').value
    assert_selector "[data-brew-grinder-reminder-target=lastUse]", text: "1/3,0"
    click_button "Save brew"
    assert_current_path %r{\A/brews/\d+\z}
    visit new_brew_path(method: "espresso")
    assert_equal "1/3,0", find('input[name="brew[grind_setting]"]').value
  end

  test "parallel coffee requires confirmation even when opened directly in Taste" do
    sign_in_through_browser
    visit new_brew_path(method: "espresso")
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    click_button "Full form"
    fill_in "Bean in (g)", with: "18"
    click_button "Taste", exact: true
    click_button "Save brew"
    assert_selector "[data-testid=brew-session-error]", text: "Confirm grinding before saving"
    assert_button "Continue to extraction"
    refresh
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    click_button "Save brew"
    assert_selector "[data-testid=brew-session-error]", text: "Confirm grinding before saving"
  end

  test "recipe and repeat context remain independent across both forms and recovery" do
    sign_in_through_browser
    recipe = recipes(:household_recipe)
    visit new_brew_path(method: "espresso", recipe_id: recipe.id)
    fill_in "Notes", with: "Recipe draft"
    recipe_key = find("[data-testid=brew-session]")["data-brew-session-storage-key-value"]
    assert_includes recipe_key, ":recipe:#{recipe.id}"
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    assert_selector "[data-brew-session-target=forms] input[type=hidden][name='brew[recipe_id]'][value='#{recipe.id}']", count: 2, visible: :all
    refresh
    assert_selector "[data-brew-session-target=forms] input[type=hidden][name='brew[recipe_id]'][value='#{recipe.id}']", count: 2, visible: :all
    visit new_brew_path(repeat_brew_id: brews(:morning_espresso).id)
    repeat_key = find("[data-testid=brew-session]")["data-brew-session-storage-key-value"]
    assert_includes repeat_key, "roastnode:brew:repeat:espresso:"
    assert_not_equal recipe_key, repeat_key
    assert_no_selector "input[name='brew[recipe_id]']", visible: :all
    assert_equal "", find('textarea[name="brew[notes]"]').value
    click_button "Prepare next coffee"
    assert_selector "[data-testid=brew-session-coffee][aria-pressed=true]", text: "Coffee 2"
    assert_equal "", find('input[name="brew[bean_weight_grams]"]').value
    click_button "Full form"
    assert_equal "", find('input[name="brew[beverage_grams]"]').value
    visit new_brew_path(method: "espresso", recipe_id: recipe.id)
    click_button "Coffee 1"
    assert_equal "Recipe draft", find('textarea[name="brew[notes]"]').value
  end

  private
    def sign_in_through_browser
      visit new_session_path
      fill_in "Email", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
