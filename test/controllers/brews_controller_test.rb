require "test_helper"

class BrewsControllerTest < ActionDispatch::IntegrationTest
  test "new redirects to new bean when workspace has no open beans" do
    workspaces(:household).beans.update_all(remaining_grams: 0, archived_at: Time.current)
    sign_in_as(users(:one))

    get new_brew_path

    assert_redirected_to new_bean_path
  end

  test "new defaults to current user's last active bean" do
    brews(:morning_espresso).update!(low_flow_start_seconds: 7, flow_control_used: true)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "h1", I18n.t("brews.new.title")
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", beans(:open_household).id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[grinder_id]", equipment(:household_grinder).id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[machine_id]", equipment(:household_machine).id.to_s
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[ground_weight_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[dose_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "40.0", count: 0
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12"
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", "93.0"
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "28", count: 0
    assert_select "input[name=?][value=?]", "brew[preinfusion_seconds]", "5"
    assert_select "input[name=?][value=?]", "brew[low_flow_start_seconds]", "7"
    assert_select "input[type=checkbox][name=?][checked]", "brew[flow_control_used]", count: 0
    assert_select "input[name=?][value=?]", "brew[first_drip_seconds]", "8", count: 0
    assert_select "input[name=?][value=?][checked]", "brew[rating]", "4", count: 0
    assert_select "input[type=datetime-local][name=?][required=required][step=?]", "brew[occurred_at]", "1"
    assert_select "textarea[name=?]", "brew[notes]", text: ""
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:puck_screen).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:other_workspace_tool).id.to_s, count: 0
    assert_select "input[type=file][name=?][multiple=multiple]", "brew[photos][]"
  end

  test "new espresso form exposes controls supported by the selected machine" do
    machine = equipment(:household_machine)
    machine.update!(preinfusion_enabled: true, low_flow_start_enabled: true, flow_control_enabled: true)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "form[data-controller~=brew-machine-features]"
    assert_select "input[type=radio][name=?][value=?][data-brew-machine-features-target=machine][data-preinfusion-enabled=true][data-low-flow-start-enabled=true][data-flow-control-enabled=true]",
      "brew[machine_id]",
      machine.id.to_s
    assert_select "[data-brew-machine-features-target=feature][data-feature=preinfusion]:not([hidden]) input[name=?]:not([disabled])", "brew[preinfusion_seconds]"
    assert_select "[data-brew-machine-features-target=feature][data-feature=lowFlowStart]:not([hidden]) input[name=?]:not([disabled])", "brew[low_flow_start_seconds]"
    assert_select "[data-brew-machine-features-target=feature][data-feature=flowControl]:not([hidden]) input[type=checkbox][name=?]:not([disabled])", "brew[flow_control_used]"
  end

  test "new espresso form disables controls unsupported by the selected machine" do
    equipment(:household_machine).update!(preinfusion_enabled: false, low_flow_start_enabled: false, flow_control_enabled: false)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "[data-brew-machine-features-target=feature][hidden]", count: 3
    assert_select "[data-feature=preinfusion] input[name=?][disabled]", "brew[preinfusion_seconds]"
    assert_select "[data-feature=lowFlowStart] input[name=?][disabled]", "brew[low_flow_start_seconds]"
    assert_select "[data-feature=flowControl] input[name=?][disabled]", "brew[flow_control_used]", minimum: 1
  end

  test "edit keeps historical machine feature values available when capabilities are disabled" do
    brew = brews(:morning_espresso)
    brew.update!(low_flow_start_seconds: 7, flow_control_used: true)
    brew.machine.update!(preinfusion_enabled: false, low_flow_start_enabled: false, flow_control_enabled: false)
    sign_in_as(users(:one))

    get edit_brew_path(brew)

    assert_response :success
    assert_select "form[data-controller~=brew-machine-features]", count: 0
    assert_select "[data-feature=preinfusion]:not([hidden]) input[name=?]:not([disabled])", "brew[preinfusion_seconds]"
    assert_select "[data-feature=lowFlowStart]:not([hidden]) input[name=?][value=7]:not([disabled])", "brew[low_flow_start_seconds]"
    assert_select "[data-feature=flowControl]:not([hidden]) input[type=checkbox][name=?][checked]:not([disabled])", "brew[flow_control_used]"
  end

  test "new back link returns to dashboard even with an in-app referrer" do
    sign_in_as(users(:one))

    get new_brew_path, headers: { "HTTP_REFERER" => "http://www.example.com#{beans_path}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      dashboard_path,
      I18n.t("brews.new.back"),
      I18n.t("brews.new.back")
    assert_select "a[data-testid=back-link] svg.material-symbol[data-symbol=arrow_back]"
    assert_select "a[data-testid=back-link]", text: /#{Regexp.escape(I18n.t("brews.new.back"))}/, count: 0
  end

  test "new places brew log time at the end of the form" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    form_body = Nokogiri::HTML(response.body).at_css("form[action='#{brews_path}']").inner_html
    log_time_index = form_body.index('data-section="log-time"')
    record_links_index = form_body.index('data-testid="record-links-fields"')
    submit_index = form_body.index('type="submit"')

    assert_not_nil log_time_index
    assert_not_nil record_links_index
    assert_not_nil submit_index
    assert_operator log_time_index, :>, record_links_index
    assert_operator log_time_index, :<, submit_index
  end

  test "new falls back to household last brew defaults for a user without household brews" do
    brews(:morning_espresso).update!(low_flow_start_seconds: 7, flow_control_used: true)
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_brew_path

    assert_response :success
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", beans(:open_household).id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[grinder_id]", equipment(:household_grinder).id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[machine_id]", equipment(:household_machine).id.to_s
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12"
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", "93.0"
    assert_select "input[name=?][value=?]", "brew[preinfusion_seconds]", "5"
    assert_select "input[name=?][value=?]", "brew[low_flow_start_seconds]", "7"
    assert_select "input[type=checkbox][name=?][checked]", "brew[flow_control_used]", count: 0
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s
  end

  test "new renders stable method tabs and defaults to last enabled method" do
    user = users(:one)
    sign_in_as(user)

    get new_brew_path(method: "quick_drip")

    assert_response :success
    assert_select "[data-testid=log-tabs].grid.overflow-hidden[style=?]", "grid-template-columns: repeat(3, minmax(0, 1fr));"
    assert_select "[data-testid=log-tabs] a.rn-method-tab", count: 3
    assert_select "a[href=?].rn-method-tab-inactive", new_brew_path(method: "espresso"), text: "Espresso"
    assert_select "a[href=?][aria-current=page].rn-method-tab-active", new_brew_path(method: "quick_drip"), text: "Quick Drip"
    assert_select "a[href=?].rn-method-tab-inactive", new_external_coffee_path, text: "External Coffee"
  end

  test "espresso new carries selected method for create" do
    sign_in_as(users(:one))

    get new_brew_path(method: "espresso")

    assert_response :success
    assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "espresso"
  end

  test "new form offers self stable household users and guest without legacy fields" do
    users(:two).update!(display_name: "Petra")
    sign_in_as(users(:one))

    get new_brew_path(method: "espresso")

    assert_response :success
    assert_select "input[type=radio][name=?][value=self][checked]", "brew[recipient_selection]"
    assert_select "input[type=radio][name=?][value=?]", "brew[recipient_selection]", "member:#{users(:two).id}"
    assert_select "input[type=radio][name=?][value=guest]", "brew[recipient_selection]"
    assert_select "label[for=brew_recipient_name]", text: "Person name"
    assert_select "input[name=?]", "brew[recipient_name]"
    assert_select "input[name=?]", "brew[served_for_guest]", count: 0
    assert_select "input[name=?]", "brew[guest_name]", count: 0
  end

  test "disabled method tab is hidden but history remains visible" do
    users(:one).update!(enabled_brew_methods: %w[espresso])
    sign_in_as(users(:one))

    get new_brew_path(method: "quick_drip")

    assert_response :success
    assert_select "a[href=?]", new_brew_path(method: "quick_drip"), count: 0
    assert_select "a[href=?][aria-current=page]", new_brew_path(method: "espresso")

    get brews_path
    assert_response :success
    assert_select "h1", I18n.t("brews.index.title")
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{Regexp.escape(brews(:morning_espresso).bean.name)}/

    get brew_path(brews(:morning_espresso))
    assert_response :success
  end

  test "quick drip new redirects to add brewer when no brewer exists" do
    workspaces(:household).equipment.brewer.destroy_all
    sign_in_as(users(:one))

    get new_brew_path(method: "quick_drip")

    assert_redirected_to new_equipment_path(kind: "brewer")
    assert_equal I18n.t("brews.new.needs_brewer"), flash[:alert]
  end

  test "quick drip new renders batch fields and quick drip tools" do
    sign_in_as(users(:one))

    get new_brew_path(method: "quick_drip")

    assert_response :success
    assert_select "input[type=datetime-local][name=?][required=required][step=?]", "brew[occurred_at]", "1"
    assert_select "input[name=?][autofocus]", "brew[machine_cups]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[machine_cups]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[coffee_spoons]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[bean_weight_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[beverage_grams]"
    assert_select "[data-testid=brew-recipient-fields]"
    assert_select "input[type=radio][name=?][value=self][checked]", "brew[recipient_selection]"
    assert_select "input[type=text][name=?][list=brew_recipient_name_suggestions]", "brew[recipient_name]"
    assert_select "input[type=text][name=?][list=brew_cup_style_suggestions]", "brew[cup_style]"
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[brewer_id]", equipment(:household_brewer).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:paper_filter).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s, count: 0
    assert_select "[data-testid=brew-taste-balance-options]", text: /Weak/
    assert_select "[data-testid=brew-taste-balance-options]", text: /Balanced/
    assert_select "[data-testid=brew-taste-balance-options]", text: /Harsh/
    assert_select "input[type=radio][name=?][value=?]", "brew[taste_balance]", "very_sour", count: 0
    assert_select "input[type=radio][name=?][value=?]", "brew[taste_balance]", "very_bitter", count: 0
    assert_select "input[name=?]", "brew[brew_temperature_celsius]", count: 0
    assert_select "input[name=?]", "brew[preinfusion_seconds]", count: 0
    assert_select "input[name=?]", "brew[low_flow_start_seconds]", count: 0
    assert_select "input[name=?]", "brew[first_drip_seconds]", count: 0
    assert_select "input[name=?]", "brew[channeling]", count: 0
    assert_select "input[name=?]", "brew[flow_control_used]", count: 0
  end

  test "new with repeat brew copies targetable values and keeps outcome fields fresh" do
    source = brews(:morning_espresso)
    source.update!(
      bean_weight_grams: 18.5,
      ground_weight_grams: 18.4,
      dose_grams: 18.3,
      beverage_grams: 45.5,
      grind_setting: "12.5",
      brew_temperature_celsius: 92.5,
      preinfusion_seconds: 6,
      low_flow_start_seconds: 7,
      first_drip_seconds: 9,
      total_time_seconds: 31,
      rating: 5,
      taste_balance: "sour",
      channeling: true,
      flow_control_used: true,
      notes: "Do not copy private notes.",
      public_note: "Do not copy public notes."
    )
    source.record_links.create!(
      label: "Private reference",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private"
    )
    sign_in_as(users(:one))

    get new_brew_path(repeat_brew_id: source.id)

    assert_response :success
    assert_select "[data-testid=repeat-brew-notice]", text: /Repeating/
    assert_select "form[data-controller~=?][data-brew-draft-storage-key-value=?]",
      "brew-draft",
      "roastnode:brew:repeat:#{source.method}:#{workspaces(:household).id}:#{users(:one).id}:#{source.id}"
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", source.bean.id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[grinder_id]", source.grinder.id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[machine_id]", source.machine.id.to_s
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.5"
    assert_select "input[name=?][value=?]", "brew[ground_weight_grams]", "18.4"
    assert_select "input[name=?][value=?]", "brew[dose_grams]", "18.3"
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "45.5"
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12.5"
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", "92.5"
    assert_select "input[name=?][value=?]", "brew[preinfusion_seconds]", "6"
    assert_select "input[name=?][value=?]", "brew[low_flow_start_seconds]", "7"
    assert_select "input[name=?][value=?]", "brew[first_drip_seconds]", "9"
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "31"
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s
    assert_select "input[name=?][value=?][checked]", "brew[rating]", "5", count: 0
    assert_select "input[name=?][value=?][checked]", "brew[taste_balance]", "sour", count: 0
    assert_select "input[name=?][checked]", "brew[channeling]", count: 0
    assert_select "input[type=checkbox][name=?][checked]", "brew[flow_control_used]", count: 0
    assert_select "textarea[name=?]", "brew[notes]", text: ""
    assert_select "textarea[name=?]", "brew[public_note]", text: ""
    assert_select "input[name*='[record_links_attributes]'][value='Private reference']", count: 0
  end

  test "new with repeat brew uses source method when latest brew is quick drip" do
    user = users(:one)
    create_latest_quick_drip_brew_for(user)
    source = brews(:morning_espresso)
    sign_in_as(user)

    get new_brew_path(repeat_brew_id: source.id)

    assert_response :success
    assert_select "[data-testid=repeat-brew-notice]", text: /Repeating/
    assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "espresso"
    assert_select "input[name=?][value=?]", "brew[grind_setting]", source.grind_setting
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", source.brew_temperature_celsius.to_s
    assert_select "input[name=?]", "brew[machine_cups]", count: 0
    assert_select "input[name=?]", "brew[coffee_spoons]", count: 0
    assert_select "[data-testid=brew-form-section][data-section=batch]", count: 0
  end

  test "new with repeat quick drip copies batch setup without measured coffee" do
    user = users(:one)
    source = create_spoon_estimated_quick_drip_brew_for(user)
    sign_in_as(user)

    get new_brew_path(repeat_brew_id: source.id)

    assert_response :success
    assert_equal "estimated_spoons", source.coffee_amount_source
    assert_select "[data-testid=repeat-brew-notice]", text: /Repeating/
    assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "quick_drip"
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[brewer_id]", source.brewer.id.to_s
    assert_select "input[name=?][value=?]", "brew[machine_cups]", source.machine_cups.to_s
    assert_select "input[name=?][value=?]", "brew[coffee_spoons]", source.coffee_spoons.to_s
    assert_select "input[type=hidden][name=?][value=?]", "brew[grams_per_coffee_spoon]", source.grams_per_coffee_spoon.to_s
    assert_select "input[name=?][value]", "brew[bean_weight_grams]", count: 0
    assert_select "input[name=?]", "brew[brew_temperature_celsius]", count: 0
    assert_select "input[name=?]", "brew[preinfusion_seconds]", count: 0
    assert_select "input[name=?]", "brew[first_drip_seconds]", count: 0
    assert_select "input[name=?][value=?][checked]", "brew[rating]", source.rating.to_s, count: 0
    assert_select "input[name=?][value=?][checked]", "brew[taste_balance]", source.taste_balance, count: 0
    assert_select "textarea[name=?]", "brew[notes]", text: ""
    assert_select "[data-testid=brew-form-section][data-section=batch]"
  end

  test "new with repeat quick drip redirects when quick drip is disabled" do
    user = users(:one)
    source = create_spoon_estimated_quick_drip_brew_for(user)
    user.update!(enabled_brew_methods: %w[espresso])
    sign_in_as(user)

    get new_brew_path(repeat_brew_id: source.id)

    assert_redirected_to new_brew_path
    assert_equal I18n.t("brews.new.repeat_method_disabled", method: I18n.t("brews.methods.quick_drip")), flash[:alert]
  end

  test "quick drip repeat copies method target fields and keeps subjective fields fresh" do
    source = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:open_household),
      brewer: equipment(:household_brewer),
      grinder: equipment(:household_grinder),
      machine_cups: 6,
      coffee_spoons: 6,
      bean_weight_grams: 31,
      beverage_grams: 900,
      total_time_seconds: 320,
      grind_setting: "filter 8",
      taste_balance: "bitter",
      rating: 5,
      notes: "Do not copy."
    )
    source.snapshot_preparation_tools!([ preparation_tools(:paper_filter) ])
    sign_in_as(users(:one))

    get new_brew_path(repeat_brew_id: source.id)

    assert_response :success
    assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "quick_drip"
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[brewer_id]", source.brewer.id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[grinder_id]", source.grinder.id.to_s
    assert_select "input[name=?][value=?]", "brew[machine_cups]", "6.0"
    assert_select "input[name=?][value=?]", "brew[coffee_spoons]", "6.0"
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "31.0"
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "900.0"
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "320"
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "filter 8"
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:paper_filter).id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[taste_balance]", "bitter", count: 0
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[rating]", "5", count: 0
    assert_select "textarea[name=?]", "brew[notes]", text: ""
  end

  test "new with repeat brew uses newest open duplicated follow-up bag when source bean is closed" do
    source = brews(:morning_espresso)
    original = source.bean
    older_duplicate = original.duplicate_for_new_bag!
    older_duplicate.update!(opened_on: Date.new(2026, 5, 30), remaining_grams: 0, finished_at: Time.zone.local(2026, 6, 1, 9, 0, 0))
    newer_duplicate = older_duplicate.duplicate_for_new_bag!
    newer_duplicate.update!(opened_on: Date.new(2026, 6, 2))
    original.update!(remaining_grams: 0, finished_at: Time.zone.local(2026, 6, 1, 9, 0, 0))
    sign_in_as(users(:one))

    get new_brew_path(repeat_brew_id: source.id)

    assert_response :success
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", newer_duplicate.id.to_s
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", original.id.to_s, count: 0
    assert_select "[data-testid=repeat-brew-follow-up-bean]", text: /#{Regexp.escape(newer_duplicate.display_name)}/
    assert_select "input[name=?][value=?]", "brew[grind_setting]", source.grind_setting
  end

  test "new with repeat brew redirects when source bean and duplicate family are closed" do
    source = brews(:morning_espresso)
    original = source.bean
    duplicate = original.duplicate_for_new_bag!
    original.update!(remaining_grams: 0, finished_at: Time.zone.local(2026, 6, 1, 9, 0, 0))
    duplicate.update!(remaining_grams: 0, finished_at: Time.zone.local(2026, 6, 2, 9, 0, 0))
    sign_in_as(users(:one))

    get new_brew_path(repeat_brew_id: source.id)

    assert_redirected_to new_brew_path
    assert_equal I18n.t("brews.new.repeat_source_unavailable"), flash[:alert]
    follow_redirect!
    assert_response :success
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", beans(:second_open_household).id.to_s
  end

  test "new with repeat brew rejects cross workspace source" do
    sign_in_as(users(:one))

    get new_brew_path(repeat_brew_id: brews(:other_workspace_brew).id)

    assert_response :not_found
  end

  test "new with recipe shows target guide without overriding brew defaults" do
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["targets"].merge!(
      "bean_weight_grams" => "19.5",
      "dose_grams" => "19.2",
      "beverage_grams" => "48.0",
      "grind_setting" => "10",
      "total_time_seconds" => 34
    )
    recipe.update!(profile:)
    sign_in_as(users(:one))

    get new_brew_path(recipe_id: recipe.id)

    assert_response :success
    assert_select "[data-testid=recipe-target-guide]", text: /Set grinder to 10/
    assert_select "[data-testid=recipe-target-guide]", text: /Stop at 34s/
    assert_select "input[type=hidden][name=?][value=?]", "brew[recipe_id]", recipe.id.to_s
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12"
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "19.5", count: 0
    assert_select "input[name=?][value=?]", "brew[dose_grams]", "19.2", count: 0
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "48.0", count: 0
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "34", count: 0
  end

  test "new with recipe stays espresso when latest brew is quick drip" do
    user = users(:one)
    create_latest_quick_drip_brew_for(user)
    recipe = recipes(:household_recipe)
    sign_in_as(user)

    get new_brew_path(recipe_id: recipe.id)

    assert_response :success
    assert_select "[data-testid=recipe-target-guide]"
    assert_select "input[type=hidden][name=?][value=?]", "brew[recipe_id]", recipe.id.to_s
    assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "espresso"
    assert_select "input[name=?]", "brew[brew_temperature_celsius]"
    assert_select "input[name=?]", "brew[preinfusion_seconds]"
    assert_select "input[name=?]", "brew[machine_cups]", count: 0
    assert_select "input[name=?]", "brew[coffee_spoons]", count: 0
    assert_select "[data-testid=brew-form-section][data-section=batch]", count: 0
  end

  test "new brew with recipe renders recipe finish card without pre-filling brew fields" do
    sign_in_as(users(:one))
    recipe = recipes(:household_recipe)
    profile = recipe.profile.deep_dup
    profile["ingredients"] = [
      { "amount" => "200", "unit" => "ml", "name" => "matcha" }
    ]
    profile["finish_note"] = "Pour espresso over matcha."
    recipe.update!(profile:)

    get new_brew_path(recipe_id: recipe.id)

    assert_response :success
    assert_select "[data-testid=recipe-finish-card]", text: /200 ml matcha/
    assert_select "[data-testid=recipe-finish-card]", text: /Pour espresso over matcha/
    assert_select "input[name='brew[dose_grams]'][value='18.0']", count: 0
  end

  test "new with cross workspace recipe is not found" do
    sign_in_as(users(:one))

    get new_brew_path(recipe_id: recipes(:other_workspace_recipe).id)

    assert_response :not_found
  end

  test "new does not offer archived equipment" do
    archived_grinder = equipment(:household_grinder)
    archived_machine = equipment(:household_machine)
    archived_grinder.update!(archived_at: Time.current)
    archived_machine.update!(archived_at: Time.current)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[type=radio][name=?][value=?]", "brew[grinder_id]", archived_grinder.id.to_s, count: 0
    assert_select "input[type=radio][name=?][value=?]", "brew[machine_id]", archived_machine.id.to_s, count: 0
  end

  test "new autofocuses the user's preferred brew field" do
    users(:one).update!(default_brew_focus_field: "dose_grams")
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[name=?][autofocus]", "brew[dose_grams]"
    assert_select "input[name=?][autofocus]", "brew[bean_weight_grams]", count: 0
  end

  test "new hides the user's optional brew fields" do
    users(:one).update!(hidden_brew_field_names: %w[rating channeling notes photos])
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[name=?]", "brew[rating]", count: 0
    assert_select "input[name=?]", "brew[channeling]", count: 0
    assert_select "textarea[name=?]", "brew[notes]", count: 0
    assert_select "textarea[name=?]", "brew[public_note]"
    assert_select "input[type=file][name=?]", "brew[photos][]", count: 0
    assert_select "input[name=?]", "brew[bean_weight_grams]"
  end

  test "new renders decimal measurement fields as comma-friendly text inputs" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[bean_weight_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[ground_weight_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[dose_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[beverage_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "brew[brew_temperature_celsius]"
  end

  test "new wires one way ground out to dose sync when both fields render" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "form[data-controller~=?]", "brew-dose-sync"
    assert_select "input[name=?][data-brew-dose-sync-target=?][data-action=?]",
      "brew[ground_weight_grams]",
      "groundWeight",
      "input->brew-dose-sync#groundWeightChanged"
    assert_select "input[name=?][data-brew-dose-sync-target=?][data-action=?]",
      "brew[dose_grams]",
      "dose",
      "input->brew-dose-sync#doseChanged"
  end

  test "new skips dose sync when dose is hidden" do
    users(:one).update!(hidden_brew_field_names: %w[dose_grams])
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "form[data-controller~=?]", "brew-dose-sync", count: 0
    assert_select "input[name=?]", "brew[ground_weight_grams]"
    assert_select "input[name=?]", "brew[dose_grams]", count: 0
  end

  test "brew form renders rating as constrained choices" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[type=number][name=?]", "brew[rating]", count: 0
    assert_select "[data-testid=brew-rating-options]"
    assert_select "input[type=radio][name=?]", "brew[rating]", count: 6
    assert_select "input[type=radio][name=?][value=''][checked]", "brew[rating]"
    (1..5).each do |rating|
      assert_select "input[type=radio][name=?][value=?]", "brew[rating]", rating.to_s
    end
  end

  test "brew form renders taste balance as styled choices" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "select[name=?]", "brew[taste_balance]", count: 0
    assert_select "[data-testid=brew-taste-balance-options]"
    assert_select "input[type=radio][name=?]", "brew[taste_balance]", count: Brew.taste_balances.size
    assert_select "[data-testid=brew-taste-unknown-choice] input[type=radio][name=?][value=?]",
      "brew[taste_balance]",
      "unknown"
    assert_select "[data-testid=brew-taste-balance-scale] input[type=radio][name=?]", "brew[taste_balance]", count: Brew.taste_balances.size - 1
    assert_select "[data-testid=brew-taste-balance-scale] input[type=radio][value=?]", "unknown", count: 0
    assert_select "input[type=radio][name=?][value=?]", "brew[taste_balance]", "neutral"
    assert_select ".rn-choice-label", text: "Neutral"
  end

  test "new renders shot-first form sections in approved order" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "[data-testid=brew-form-section][data-section=bean]"
    assert_select "[data-testid=brew-form-section][data-section=dose]"
    assert_select "[data-testid=brew-form-section][data-section=extraction]"
    assert_select "[data-testid=brew-form-section][data-section=setup]"
    assert_select "[data-testid=brew-form-section][data-section=taste]"
    assert_select "[data-testid=brew-form-section][data-section=notes]"

    assert_appears_before "data-section=\"bean\"", "data-section=\"dose\""
    assert_appears_before "data-section=\"dose\"", "data-section=\"extraction\""
    assert_appears_before "data-section=\"extraction\"", "data-section=\"setup\""
    assert_appears_before "data-section=\"setup\"", "data-section=\"taste\""
    assert_appears_before "data-section=\"taste\"", "data-section=\"notes\""

    assert_appears_before "brew[bean_weight_grams]", "brew[ground_weight_grams]"
    assert_appears_before "brew[ground_weight_grams]", "brew[dose_grams]"
    assert_appears_before "brew[dose_grams]", "brew[grind_setting]"
    assert_appears_before "brew[preinfusion_seconds]", "brew[first_drip_seconds]"
    assert_appears_before "brew[preinfusion_seconds]", "brew[low_flow_start_seconds]"
    assert_appears_before "brew[low_flow_start_seconds]", "brew[first_drip_seconds]"
    assert_appears_before "brew[first_drip_seconds]", "brew[total_time_seconds]"
    assert_appears_before "brew[total_time_seconds]", "brew[beverage_grams]"
    assert_appears_before "brew[channeling]", "brew[flow_control_used]"
    assert_appears_before "brew[flow_control_used]", "brew[photos][]"
    assert_appears_before "brew[channeling]", "brew[photos][]"
    assert_appears_before "brew[photos][]", "brew[grinder_id]"
    assert_appears_before "brew[machine_id]", "brew[brew_temperature_celsius]"
    assert_appears_before "brew[taste_balance]", "brew[rating]"
    assert_appears_before "brew[rating]", "brew[notes]"
  end

  test "new renders image-backed selectors for beans equipment and preparation tools" do
    bean_photo = attach_photo(beans(:open_household))
    grinder_photo = attach_photo(equipment(:household_grinder))
    machine_photo = attach_photo(equipment(:household_machine))
    tool_photo = attach_photo(preparation_tools(:wdt))
    beans(:open_household).set_primary_photo!(bean_photo)
    equipment(:household_grinder).set_primary_photo!(grinder_photo)
    equipment(:household_machine).set_primary_photo!(machine_photo)
    preparation_tools(:wdt).set_primary_photo!(tool_photo)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", beans(:open_household).id.to_s
    assert_select "img[data-testid=brew-bean-option-photo][src=?]", media_attachment_path(bean_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-grinder-option-photo][src=?]", media_attachment_path(grinder_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-machine-option-photo][src=?]", media_attachment_path(machine_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-tool-option-photo][src=?]", media_attachment_path(tool_photo, variant: :thumbnail)
  end

  test "edit ignores hidden brew fields so corrections show the full log" do
    users(:one).update!(hidden_brew_field_names: %w[rating channeling notes photos])
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "input[name=?]", "brew[rating]"
    assert_select "input[name=?]", "brew[channeling]"
    assert_select "textarea[name=?]", "brew[notes]"
    assert_select "input[type=file][name=?]", "brew[photos][]"
  end

  test "new wires browser draft recovery to the current user and workspace" do
    user = users(:one)
    workspace = workspaces(:household)
    sign_in_as(user)

    get new_brew_path

    assert_response :success
    assert_select "form[data-controller~=?][data-brew-draft-storage-key-value=?]",
      "brew-draft",
      "roastnode:brew:new:espresso:#{workspace.id}:#{user.id}"
    assert_select "[data-brew-draft-target=?].hidden", "notice"
    assert_select "button[type=button][data-action=?]", "brew-draft#discard", text: I18n.t("brews.form.discard_draft")
  end

  test "edit does not wire browser draft recovery" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "form[data-controller~=?]", "brew-draft", count: 0
  end

  test "brew edit form renders public note and record links" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "textarea[name=?]", "brew[public_note]"
    assert_select "[data-testid=record-links-fields]"
    assert_select "input[name*='[record_links_attributes]'][name$='[label]']"
    assert_select "input[name*='[record_links_attributes]'][name$='[url]']"
    assert_select "select[name*='[record_links_attributes]'][name$='[kind]']"
    assert_select "select[name*='[record_links_attributes]'][name$='[visibility]']"
    assert_select "select[name*='[record_links_attributes]'][name$='[visibility]'] option[value=private][selected]"
  end

  test "brew edit form keeps a blank link row after three saved links" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    3.times do |index|
      brew.record_links.create!(
        label: "Link #{index}",
        url: "https://example.com/#{index}",
        kind: "info",
        visibility: "private",
        position: index * 10
      )
    end

    get edit_brew_path(brew)

    assert_response :success
    assert_select "input[name*='[record_links_attributes]'][name$='[label]']", minimum: 4
  end

  test "writer can update brew public note and public links" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    share = create_public_bean_share_for(brew.bean)
    peer_share = create_public_bean_share_for(beans(:second_open_household))
    peer_share.update_columns(snapshot: peer_share.snapshot.merge("metadata_marker" => "untouched"))

    patch brew_path(brew), params: {
      brew: {
        bean_id: brew.bean.id,
        grinder_id: brew.grinder.id,
        machine_id: brew.machine.id,
        bean_weight_grams: brew.bean_weight_grams.to_s,
        public_note: "Public brew note.",
        record_links_attributes: {
          "0" => {
            label: "Shot writeup",
            url: "https://example.com/shot",
            kind: "info",
            visibility: "public",
            position: "10"
          }
        }
      }
    }

    assert_redirected_to brew_path(brew)
    assert_equal "Public brew note.", brew.reload.public_note
    assert_equal "Shot writeup", brew.record_links.first.label
    assert_equal "public", brew.record_links.first.visibility
    assert_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "Public brew note."
    assert_equal "untouched", peer_share.reload.snapshot["metadata_marker"]
  end

  test "brew metric updates refresh peer public bean comparison snapshots" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    peer_bean = beans(:second_open_household)
    peer_bean.workspace.brews.create!(
      user: users(:one),
      bean: peer_bean,
      method: "espresso",
      bean_weight_grams: 18,
      rating: 5,
      channeling: true
    )
    peer_share = create_public_bean_share_for(peer_bean)

    assert_equal 2, peer_share.snapshot.dig("comparisons", "channeling", "rank")

    patch brew_path(brew), params: {
      brew: {
        bean_id: brew.bean.id,
        grinder_id: brew.grinder.id,
        machine_id: brew.machine.id,
        bean_weight_grams: brew.bean_weight_grams.to_s,
        ground_weight_grams: brew.ground_weight_grams.to_s,
        dose_grams: brew.dose_grams.to_s,
        beverage_grams: brew.beverage_grams.to_s,
        total_time_seconds: brew.total_time_seconds.to_s,
        taste_balance: brew.taste_balance,
        rating: "5",
        channeling: "1"
      }
    }

    assert_redirected_to brew_path(brew)
    assert_equal 1, peer_share.reload.snapshot.dig("comparisons", "channeling", "rank")
  end

  test "moving brew to another bean refreshes old public bean snapshot" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.update!(public_note: "Moved brew public note")
    old_bean = brew.bean
    new_bean = beans(:second_open_household)
    share = create_public_bean_share_for(old_bean)

    patch brew_path(brew), params: {
      brew: {
        bean_id: new_bean.id,
        grinder_id: brew.grinder.id,
        machine_id: brew.machine.id,
        bean_weight_grams: brew.bean_weight_grams.to_s,
        ground_weight_grams: brew.ground_weight_grams.to_s,
        dose_grams: brew.dose_grams.to_s,
        beverage_grams: brew.beverage_grams.to_s,
        total_time_seconds: brew.total_time_seconds.to_s,
        taste_balance: brew.taste_balance
      }
    }

    assert_redirected_to brew_path(brew)
    assert_not_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "Moved brew public note"
  end

  test "writer can update brew log time and inventory adjustment time" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    new_time = Time.find_zone("Europe/Berlin").local(2026, 5, 27, 10, 15, 28)

    get edit_brew_path(brew)

    assert_response :success
    assert_select "input[type=datetime-local][name=?][required=required][step=?]", "brew[occurred_at]", "1"

    patch brew_path(brew), params: {
      brew: {
        bean_id: brew.bean.id,
        grinder_id: brew.grinder.id,
        machine_id: brew.machine.id,
        occurred_at: "2026-05-27T10:15:28",
        bean_weight_grams: brew.bean_weight_grams.to_s,
        ground_weight_grams: brew.ground_weight_grams.to_s,
        dose_grams: brew.dose_grams.to_s,
        beverage_grams: brew.beverage_grams.to_s,
        total_time_seconds: brew.total_time_seconds.to_s,
        taste_balance: brew.taste_balance
      }
    }

    assert_redirected_to brew_path(brew)
    assert_equal new_time, brew.reload.occurred_at
    assert_equal new_time, brew.inventory_adjustment.reload.occurred_at
  end

  test "datetime fields render and submit in user timezone" do
    user = users(:one)
    user.update!(time_zone: "Europe/Berlin")
    sign_in_as(user)
    brew = brews(:morning_espresso)
    brew.update!(occurred_at: Time.utc(2026, 6, 14, 8, 15, 28))

    get edit_brew_path(brew)

    assert_response :success
    assert_select "input[type=datetime-local][name=?][value=?]",
      "brew[occurred_at]",
      "2026-06-14T10:15:28"

    patch brew_path(brew), params: {
      brew: {
        bean_id: brew.bean.id,
        grinder_id: brew.grinder.id,
        machine_id: brew.machine.id,
        occurred_at: "2026-06-14T10:45:28",
        bean_weight_grams: brew.bean_weight_grams.to_s,
        ground_weight_grams: brew.ground_weight_grams.to_s,
        dose_grams: brew.dose_grams.to_s,
        beverage_grams: brew.beverage_grams.to_s,
        total_time_seconds: brew.total_time_seconds.to_s,
        taste_balance: brew.taste_balance
      }
    }

    assert_redirected_to brew_path(brew)
    assert_equal Time.utc(2026, 6, 14, 8, 45, 28), brew.reload.occurred_at
  end

  test "new falls back to first open bean when last bean is closed" do
    beans(:open_household).update!(archived_at: Time.current, remaining_grams: 0)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[bean_id]", beans(:second_open_household).id.to_s
  end

  test "new disambiguates duplicate open bean labels with opened date" do
    duplicate = workspaces(:household).beans.create!(
      name: beans(:open_household).name,
      roaster_name: beans(:open_household).roaster_name,
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.new(2026, 5, 20)
    )
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "label", text: /Good Coffee - House Blend \(opened 10\.05\.2026\)/
    assert_select "label", text: /Good Coffee - House Blend \(opened 20\.05\.2026\)/
    assert_select "label", text: /North Star - Morning Lot/
  end

  test "member can create espresso brew and consume selected bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:second_open_household)

    assert_difference -> { workspaces(:household).brews.count }, 1 do
      assert_difference -> { InventoryAdjustment.count }, 1 do
        assert_difference -> { BrewPreparationTool.count }, 2 do
          assert_activity_event(action: "brew.created", workspace: bean.workspace, actor: user) do
            post brews_path, params: {
              brew: {
                bean_id: bean.id,
                grinder_id: equipment(:household_grinder).id,
                machine_id: equipment(:household_machine).id,
                bean_weight_grams: "18.5",
                ground_weight_grams: "18.3",
                dose_grams: "18.2",
                beverage_grams: "42",
                grind_setting: "14",
                total_time_seconds: "31",
                low_flow_start_seconds: "7",
                taste_balance: "neutral",
                rating: "4",
                flow_control_used: "1",
                photos: [ photo_upload ],
                preparation_tool_ids: [
                  preparation_tools(:wdt).id,
                  preparation_tools(:other_workspace_tool).id,
                  preparation_tools(:puck_screen).id
                ]
              }
            }
          end
        end
      end
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 201.5.to_d, bean.reload.remaining_grams
    assert_equal [ "WDT", "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
    assert_equal 7, brew.low_flow_start_seconds
    assert_predicate brew, :flow_control_used?
    assert_equal 1, brew.photos.count
  end

  test "create records domain occurrence and taste serving update and delete use explicit actions" do
    sign_in_as(users(:one))
    occurred_at = Time.zone.local(2026, 8, 20, 7, 15)

    event = assert_activity_event(action: "brew.created", workspace: workspaces(:household), actor: users(:one)) do
      post brews_path, params: { brew: {
        method: "espresso", bean_id: beans(:open_household).id,
        grinder_id: equipment(:household_grinder).id, machine_id: equipment(:household_machine).id,
        occurred_at:, bean_weight_grams: "1", ground_weight_grams: "1",
        dose_grams: "1", beverage_grams: "2", taste_balance: "neutral"
      } }
    end
    assert_equal occurred_at, event.occurred_at

    brew = event.subject
    assert_activity_event(action: "brew.taste_changed", workspace: workspaces(:household), actor: users(:one), subject: brew) do
      patch taste_brew_path(brew), params: { brew: { rating: 5, taste_balance: "bitter" } }
    end
    assert_activity_event(action: "brew.serving_changed", workspace: workspaces(:household), actor: users(:one), subject: brew) do
      patch serving_brew_path(brew), params: { brew: { recipient_selection: "guest", recipient_name: "Guest" } }
    end
    assert_activity_event(action: "brew.deleted", workspace: workspaces(:household), actor: users(:one)) do
      delete brew_path(brew)
    end
    assert_equal event.metadata.fetch("subject_label"), ActivityEvent.where(action: "brew.deleted").order(:id).last.metadata.fetch("subject_label")
  end

  test "invalid create emits nothing" do
    sign_in_as(users(:one))
    assert_no_difference -> { ActivityEvent.count } do
      post brews_path, params: { brew: { method: "espresso", bean_weight_grams: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "bean depletion emits only brew created plus the documented used up transition" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(remaining_grams: 1)

    event = assert_activity_event(
      action: "brew.created", workspace: bean.workspace, actor: users(:one),
      additional_actions: [ "bean.used_up" ]
    ) do
      post brews_path, params: { brew: {
        method: "espresso", bean_id: bean.id, grinder_id: equipment(:household_grinder).id,
        machine_id: equipment(:household_machine).id, bean_weight_grams: "1", dose_grams: "1",
        beverage_grams: "2", taste_balance: "neutral"
      } }
    end

    assert_predicate bean.reload, :used_up?
    assert_equal "brew.created", event.action
  end

  test "create rolls back brew inventory activity and refreshed snapshots when a refresher fails" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    share = create_public_bean_share_for(bean)
    original_snapshot = share.snapshot.deep_dup
    original_remaining = bean.remaining_grams
    failing_refresh = lambda do |_record|
      share.update!(snapshot: share.snapshot.merge("rollback_marker" => true))
      raise "public snapshot refresh failed"
    end

    assert_no_difference -> { ActivityEvent.count } do
      assert_no_difference -> { Brew.count } do
        with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_comparisons_for, failing_refresh) do
          assert_raises(RuntimeError) do
            post brews_path, params: { brew: {
              method: "espresso", bean_id: bean.id, grinder_id: equipment(:household_grinder).id,
              machine_id: equipment(:household_machine).id, bean_weight_grams: "18", dose_grams: "18",
              beverage_grams: "40", taste_balance: "neutral"
            } }
          end
        end
      end
    end
    assert_equal original_remaining, bean.reload.remaining_grams
    assert_equal original_snapshot, share.reload.snapshot
  end

  test "coffee and inventory activity contract exposes the exact approved actions" do
    assert_equal %w[
      brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated
      external_coffee.created external_coffee.updated external_coffee.deleted external_coffee.media_updated
      bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened bean.deleted bean.media_updated
      inventory_adjustment.created
    ].sort, Activity::EventContract.actions.grep(/\A(?:brew|external_coffee|bean|inventory_adjustment)\./).sort
  end

  test "member can create espresso brew with a guest recipient" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:second_open_household)

    post brews_path, params: {
      brew: {
        bean_id: bean.id,
        grinder_id: equipment(:household_grinder).id,
        machine_id: equipment(:household_machine).id,
        bean_weight_grams: "18.5",
        dose_grams: "18.2",
        beverage_grams: "42",
        total_time_seconds: "31",
        recipient_selection: "guest",
        recipient_name: "  Anna  ",
        cup_style: "  Latte  "
      }
    }

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_predicate brew, :recipient_guest?
    assert_equal "Anna", brew.recipient_name
    assert_equal "Latte", brew.cup_style
  end

  test "creating brew for shared bean refreshes public bean snapshot" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:second_open_household)
    share = create_public_bean_share_for(bean)
    sign_in_as(user)

    post brews_path, params: {
      brew: {
        bean_id: bean.id,
        grinder_id: equipment(:household_grinder).id,
        machine_id: equipment(:household_machine).id,
        bean_weight_grams: "18.5",
        dose_grams: "18.2",
        beverage_grams: "42",
        total_time_seconds: "31",
        public_note: "Fresh public bean brew",
        taste_balance: "neutral"
      }
    }

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "Fresh public bean brew"
  end

  test "member can create espresso brew with comma decimal measurements" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:second_open_household)

    assert_difference -> { workspaces(:household).brews.count }, 1 do
      post brews_path, params: {
        brew: {
          bean_id: bean.id,
          bean_weight_grams: "18,5g",
          ground_weight_grams: "18,3",
          dose_grams: "18,2",
          beverage_grams: "42,7 g",
          brew_temperature_celsius: "93,5°C",
          total_time_seconds: "31",
          taste_balance: "neutral"
        }
      }
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 18.5.to_d, brew.bean_weight_grams
    assert_equal 18.3.to_d, brew.ground_weight_grams
    assert_equal 18.2.to_d, brew.dose_grams
    assert_equal 42.7.to_d, brew.beverage_grams
    assert_equal 93.5.to_d, brew.brew_temperature_celsius
    assert_equal 201.5.to_d, bean.reload.remaining_grams
  end

  test "member can create spoon estimated quick drip brew with comma decimals" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    user.update!(grams_per_coffee_spoon: 4.5)
    sign_in_as(user)
    bean = beans(:second_open_household)

    assert_difference -> { workspaces(:household).brews.quick_drip.count }, 1 do
      post brews_path, params: {
        brew: {
          method: "quick_drip",
          bean_id: bean.id,
          brewer_id: equipment(:household_brewer).id,
          machine_cups: "6,5",
          coffee_spoons: "5,5",
          beverage_grams: "900,0",
          total_time_seconds: "320",
          taste_balance: "neutral",
          rating: "4",
          preparation_tool_ids: [ preparation_tools(:paper_filter).id, preparation_tools(:wdt).id ]
        }
      }
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 6.5.to_d, brew.machine_cups
    assert_equal 5.5.to_d, brew.coffee_spoons
    assert_equal 24.75.to_d, brew.bean_weight_grams
    assert_equal "estimated_spoons", brew.coffee_amount_source
    assert_equal [ "Paper filter" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  test "repeated spoon estimated quick drip create persists estimated spoon source" do
    user = users(:one)
    source = create_spoon_estimated_quick_drip_brew_for(user)
    sign_in_as(user)

    assert_difference -> { workspaces(:household).brews.quick_drip.count }, 1 do
      post brews_path, params: {
        brew: {
          method: "quick_drip",
          bean_id: source.bean_id,
          brewer_id: source.brewer_id,
          grinder_id: source.grinder_id,
          machine_cups: source.machine_cups.to_s,
          coffee_spoons: source.coffee_spoons.to_s,
          bean_weight_grams: "",
          grams_per_coffee_spoon: source.grams_per_coffee_spoon.to_s,
          beverage_grams: source.beverage_grams.to_s,
          total_time_seconds: source.total_time_seconds.to_s,
          grind_setting: source.grind_setting,
          taste_balance: "unknown",
          preparation_tool_ids: [ preparation_tools(:paper_filter).id ]
        }
      }
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal "quick_drip", brew.method
    assert_equal "estimated_spoons", brew.coffee_amount_source
    assert_equal source.coffee_spoons, brew.coffee_spoons
    assert_equal source.grams_per_coffee_spoon, brew.grams_per_coffee_spoon
    assert_equal source.bean_weight_grams, brew.bean_weight_grams
  end

  test "create with disabled quick drip method does not fallback to espresso" do
    user = users(:one)
    user.update!(enabled_brew_methods: %w[espresso])
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).brews.count } do
      post brews_path, params: {
        brew: {
          method: "quick_drip",
          bean_id: beans(:second_open_household).id,
          brewer_id: equipment(:household_brewer).id,
          machine_cups: "6",
          coffee_spoons: "6",
          taste_balance: "neutral"
        }
      }
    end

    assert_redirected_to new_brew_path
    assert_equal I18n.t("brews.create.method_disabled", method: I18n.t("brews.methods.quick_drip")), flash[:alert]
  end

  test "invalid quick drip create does not render cross workspace selected records" do
    sign_in_as(users(:one))
    other_bean = beans(:other_workspace_open)
    other_grinder = equipment(:other_workspace_grinder)
    other_brewer = workspaces(:other_household).equipment.create!(
      name: "Other Workspace Brewer",
      kind: "brewer"
    )

    post brews_path, params: {
      brew: {
        method: "quick_drip",
        bean_id: other_bean.id,
        grinder_id: other_grinder.id,
        brewer_id: other_brewer.id,
        machine_cups: "",
        coffee_spoons: "",
        beverage_grams: "900",
        total_time_seconds: "320",
        taste_balance: "neutral"
      }
    }

    assert_response :unprocessable_entity
    assert_no_match other_bean.name, response.body
    assert_no_match other_brewer.name, response.body
    assert_no_match other_grinder.name, response.body
    assert_select "input[type=radio][name=?][value=?]", "brew[bean_id]", other_bean.id.to_s, count: 0
    assert_select "input[type=radio][name=?][value=?]", "brew[brewer_id]", other_brewer.id.to_s, count: 0
    assert_select "input[type=radio][name=?][value=?]", "brew[grinder_id]", other_grinder.id.to_s, count: 0
  end

  test "invalid quick drip create does not render same workspace machine as brewer option" do
    sign_in_as(users(:one))
    machine = equipment(:household_machine)

    post brews_path, params: {
      brew: {
        method: "quick_drip",
        bean_id: beans(:second_open_household).id,
        brewer_id: machine.id,
        machine_cups: "",
        coffee_spoons: "",
        beverage_grams: "900",
        total_time_seconds: "320",
        taste_balance: "neutral"
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[type=radio][name=?][value=?]", "brew[brewer_id]", machine.id.to_s, count: 0
  end

  test "invalid quick drip create does not render archived brewer option" do
    sign_in_as(users(:one))
    archived_brewer = equipment(:household_brewer)
    archived_brewer.update!(archived_at: Time.current)

    post brews_path, params: {
      brew: {
        method: "quick_drip",
        bean_id: beans(:second_open_household).id,
        brewer_id: archived_brewer.id,
        machine_cups: "",
        coffee_spoons: "",
        beverage_grams: "900",
        total_time_seconds: "320",
        taste_balance: "neutral"
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[type=radio][name=?][value=?]", "brew[brewer_id]", archived_brewer.id.to_s, count: 0
  end

  test "create with recipe stores recipe reference and brew time snapshot" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    recipe = recipes(:household_recipe)

    assert_difference -> { workspaces(:household).brews.count }, 1 do
      post brews_path, params: {
        brew: {
          recipe_id: recipe.id,
          bean_id: bean.id,
          grinder_id: equipment(:household_grinder).id,
          machine_id: equipment(:household_machine).id,
          bean_weight_grams: "18.5",
          dose_grams: "18.2",
          beverage_grams: "42",
          total_time_seconds: "31",
          taste_balance: "neutral"
        }
      }
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal recipe, brew.recipe
    assert_equal recipe.profile, brew.recipe_snapshot
    assert_equal "House Blend reference", brew.recipe_snapshot["title"]
  end

  test "create with cross workspace recipe is not found" do
    sign_in_as(users(:one))

    post brews_path, params: {
      brew: {
        recipe_id: recipes(:other_workspace_recipe).id,
        bean_id: beans(:open_household).id,
        bean_weight_grams: "18",
        taste_balance: "neutral"
      }
    }

    assert_response :not_found
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(brews(:morning_espresso))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
  end

  test "show back link returns to dashboard even with an in-app referrer" do
    brew = brews(:morning_espresso)
    previous_path = "/coffees?view=hero"
    sign_in_as(users(:one))

    get brew_path(brew), headers: { "HTTP_REFERER" => "http://www.example.com#{previous_path}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      dashboard_path,
      I18n.t("brews.show.back"),
      I18n.t("brews.show.back")
    assert_select "a[data-testid=back-link] svg.material-symbol[data-symbol=arrow_back]"
    assert_select "a[data-testid=back-link]", text: /#{Regexp.escape(I18n.t("brews.show.back"))}/, count: 0
  end

  test "show back link ignores external referrers" do
    brew = brews(:morning_espresso)
    sign_in_as(users(:one))

    get brew_path(brew), headers: { "HTTP_REFERER" => "https://example.org/coffees" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      dashboard_path,
      I18n.t("brews.show.back"),
      I18n.t("brews.show.back")
  end

  test "show back link ignores public brew share workflow referrers" do
    brew = brews(:morning_espresso)
    sign_in_as(users(:one))

    get brew_path(brew), headers: { "HTTP_REFERER" => "http://www.example.com#{new_brew_public_brew_share_path(brew)}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      dashboard_path,
      I18n.t("brews.show.back"),
      I18n.t("brews.show.back")
  end

  test "show back link ignores self referrers" do
    brew = brews(:morning_espresso)
    sign_in_as(users(:one))

    get brew_path(brew), headers: { "HTTP_REFERER" => "http://www.example.com#{brew_path(brew)}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      dashboard_path,
      I18n.t("brews.show.back"),
      I18n.t("brews.show.back")
  end

  test "show renders related bean equipment and preparation tool photos" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    bean_photo = attach_photo(brew.bean)
    grinder_photo = attach_photo(brew.grinder)
    machine_photo = attach_photo(brew.machine)
    tool_photo = attach_photo(preparation_tools(:wdt))

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-related-photos]"
    assert_select "[data-testid=brew-related-photo-group]", text: /#{Regexp.escape(I18n.t("brews.show.related_bean_photos"))}/
    assert_select "[data-testid=brew-related-photo-group]", text: /#{Regexp.escape(brew.bean.display_name)}/
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(bean_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(grinder_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(machine_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(tool_photo, variant: :thumbnail)
    assert_select "a[href=?]", download_media_attachment_path(tool_photo), text: I18n.t("shared.related_photo_group.download")
  end

  test "quick drip show renders related brewer photos" do
    sign_in_as(users(:one))
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral"
    )
    brewer_photo = attach_photo(brew.brewer)

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-related-photos]"
    assert_select "[data-testid=brew-related-photo-group]", text: /#{Regexp.escape(brew.brewer.name)}/
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(brewer_photo, variant: :thumbnail)
  end

  test "show renders compact hero brew card" do
    users(:one).update!(display_name: "Jens")
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    bean_photo = attach_photo(brew.bean)
    avatar = attach_named_photo(users(:one), :avatar, filename: "avatar.jpg")
    workspace_logo = attach_named_photo(workspaces(:household), :logo, filename: "workspace-logo.jpg")
    brew.update!(
      occurred_at: Time.find_zone("Europe/Berlin").local(2026, 5, 26, 11, 22, 8),
      bean_weight_grams: 18.6,
      ground_weight_grams: 18.2,
      dose_grams: 18.2,
      beverage_grams: 45.0,
      grind_setting: "12",
      brew_temperature_celsius: 93.0,
      preinfusion_seconds: 6,
      low_flow_start_seconds: 7,
      first_drip_seconds: 8,
      total_time_seconds: 31,
      rating: 4,
      taste_balance: "neutral",
      channeling: true,
      flow_control_used: true,
      notes: "Balanced morning shot."
    )

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-hero-card]"
    assert_select "[data-testid=brew-card-header] img[data-testid=brew-card-brand-mark][alt=?]", ""
    assert_select "[data-testid=brew-card-header].flex-nowrap"
    assert_select "[data-testid=brew-timestamp].text-\\[0\\.58rem\\]"
    assert_select "[data-testid=brew-workspace].truncate"
    assert_select "[data-testid=brew-workspace] img[data-testid=brew-workspace-logo][src=?]", media_attachment_path(workspace_logo, variant: :thumbnail)
    assert_select "img[data-testid=brew-card-brand-mark][src*=?]", "logo_mark_transparent"
    assert_select "[data-testid=brew-hero-backdrop][aria-hidden=true].pointer-events-none.grid.grid-cols-2"
    assert_select "img[data-testid=brew-hero-bean-image][src=?].object-contain", media_attachment_path(bean_photo, variant: :hero)
    assert_select "[data-testid=brew-bean-photo-frame]", count: 0
    assert_select "[data-testid=brew-bean-link]", count: 0
    assert_select "[data-testid=brew-timestamp]", "26.05.2026 11:22:08"
    assert_select "[data-testid=brew-workspace]", workspaces(:household).name
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "[data-testid=brew-byline]", "Logged by Jens for themself"
    assert_select "[data-testid=brew-byline] img[data-testid=brew-logger-avatar][src=?]", media_attachment_path(avatar, variant: :thumbnail)
    assert_select "[data-testid=brew-metrics].grid-cols-3"
    assert_select "[data-testid=brew-dose]", "18,2g"
    assert_select "[data-testid=brew-beverage]", count: 0
    assert_select "[data-testid=brew-ratio-main]", "1:2,47"
    assert_select "[data-testid=brew-ratio-time]", "in 31s"
    assert_select "[data-testid=brew-grind]", "12"
    assert_select "[data-testid=brew-retention-label] .sm\\:hidden", "Retention"
    assert_select "[data-testid=brew-retention-label] .hidden.sm\\:inline", "Ret."
    assert_select "[data-testid=brew-retention-card] [data-testid=brew-retention]", "0,4g"
    assert_select "[data-testid=brew-rating-card] [data-testid=brew-rating][aria-label=?]", "Rating 4 of 5 beans" do
      assert_select ".rating-bean--filled", 4
      assert_select ".rating-bean--empty", 1
    end
    assert_select "[data-testid=brew-rating-card] [data-testid=brew-balance]", count: 0
    assert_select "[data-testid=brew-balance-card] > p", text: "Balance"
    assert_select "[data-testid=brew-balance-card] [data-testid=brew-balance]", "Neutral"
    assert_select "[data-testid=brew-balance] .block", count: 0
    assert_select "[data-testid=brew-chart-grid] svg.h-auto[viewBox='0 0 560 168']"
    assert_select "[data-testid=brew-chart-grid] svg[preserveAspectRatio]", count: 0
    assert_select "[data-testid=brew-total-time-guide][x1=?]", "500"
    assert_select "[data-testid=brew-preinfusion-label]", "6s Preinfusion"
    assert_select "[data-testid=brew-first-drip-label]", "8s First drip"
    assert_select "[data-testid=brew-first-drip-callout]"
    assert_select "[data-testid=brew-total-time-label]", "31s"
    assert_select "[data-testid=brew-temperature-label]", "Temperature 93°C"
    assert_select "[data-testid=brew-temperature-callout][transform='translate(536 132) rotate(-90)']"
    assert_select "[data-testid=brew-axis-max]", "50g"
    assert_select "[data-testid=brew-grinder-link]", count: 0
    assert_select "[data-testid=brew-machine-link]", count: 0
    assert_select "a[data-testid=brew-tool]", count: 0
    assert_select "[data-testid=brew-tool]", "WDT"
    assert_select "[data-testid=brew-log-details]"
    assert_select "[data-testid=brew-detail-bean] a[href=?]", bean_path(brew.bean), text: brew.bean.display_name
    assert_select "[data-testid=brew-detail-bean-weight]", "18,6g"
    assert_select "[data-testid=brew-detail-ground-weight]", "18,2g"
    assert_select "[data-testid=brew-detail-beverage]", "45g"
    assert_select "[data-testid=brew-detail-channeling]", "Yes"
    assert_select "[data-testid=brew-detail-low-flow-start]", "7s"
    assert_select "[data-testid=brew-detail-flow-control-used]", "Yes"
    assert_select "[data-testid=brew-detail-grinder] a[href=?]", equipment_path(brew.grinder), text: brew.grinder.name
    assert_select "[data-testid=brew-detail-machine] a[href=?]", equipment_path(brew.machine), text: brew.machine.name
    assert_select "a[data-testid=brew-detail-tool][href=?]", preparation_tool_path(preparation_tools(:wdt)), text: "WDT"
    assert_select "[data-testid=brew-detail-notes]", "Balanced morning shot."
  end

  test "espresso hero omits the preinfusion marker when no value was logged" do
    brew = brews(:morning_espresso)
    brew.update!(preinfusion_seconds: nil)
    sign_in_as(users(:one))

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-preinfusion-guide]", count: 0
    assert_select "[data-testid=brew-preinfusion-label]", count: 0
  end

  test "show renders hero ghost from brew time recipe snapshot" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.update!(
      brew_temperature_celsius: 90.0,
      recipe: recipes(:household_recipe),
      recipe_snapshot: recipes(:household_recipe).profile.deep_merge(
        "targets" => {
          "dose_grams" => "18.0",
          "beverage_grams" => "42.0",
          "grind_setting" => "10",
          "brew_temperature_celsius" => "92.0",
          "total_time_seconds" => 30,
          "preinfusion_seconds" => 6,
          "first_drip_seconds" => 9
        }
      )
    )

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-recipe-target-dose].brew-metric-target", "Target 18g"
    assert_select "[data-testid=brew-recipe-target-yield-time].brew-metric-target", "Target 42g / 30s"
    assert_select "[data-testid=brew-recipe-target-grind].brew-metric-target", "Target 10"
    assert_select "[data-testid=brew-recipe-ghost]"
    assert_select "[data-testid=brew-recipe-ghost-total-time][x1]"
    assert_select "[data-testid=brew-recipe-ghost-preinfusion-label]", "6s target"
    assert_select "[data-testid=brew-recipe-ghost-first-drip-label]", "9s target"
    assert_select "[data-testid=brew-recipe-ghost-total-time-label]", "30s target"
    assert_select "[data-testid=brew-recipe-ghost-beverage-label]", "42g target"
    assert_select "[data-testid=brew-recipe-ghost-temperature][data-position=above]"
    assert_select "[data-testid=brew-recipe-ghost-temperature-label]", "92°C target"
    assert_select "[data-testid=brew-recipe-ghost-label]", count: 0
  end

  test "show formats brew card numbers and timestamps from user profile preferences" do
    users(:one).update!(
      number_format: "dot_decimal",
      time_format: "us_12h_seconds"
    )
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.update!(
      occurred_at: Time.find_zone("Europe/Berlin").local(2026, 5, 26, 11, 22, 8),
      bean_weight_grams: 18.6,
      ground_weight_grams: 18.2,
      dose_grams: 18.2,
      beverage_grams: 45.0,
      brew_temperature_celsius: 93.0,
      total_time_seconds: 31
    )

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-timestamp]", "05/26/2026 11:22:08 AM"
    assert_select "[data-testid=brew-dose]", "18.2g"
    assert_select "[data-testid=brew-ratio-main]", "1:2.47"
    assert_select "[data-testid=brew-retention-card] [data-testid=brew-retention]", "0.4g"
    assert_select "[data-testid=brew-temperature-label]", "Temperature 93°C"
    assert_select "[data-testid=brew-detail-bean-weight]", "18.6g"
  end

  test "hero brew card uses primary bean photo" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    first = attach_photo(brew.bean)
    primary = attach_photo(brew.bean)
    brew.bean.update!(primary_photo_attachment_id: primary.id)

    get brew_path(brew)

    assert_response :success
    assert_select "img[data-testid=brew-hero-bean-image][src=?].object-contain", media_attachment_path(primary, variant: :hero)
    assert_select "img[data-testid=brew-hero-bean-image][src=?]", media_attachment_path(first, variant: :hero), count: 0
  end

  test "private heroes keep independent two-photo backdrops across every method and image state" do
    sign_in_as(users(:one))

    %w[espresso quick_drip].product([ [], [ :bean ], [ :brew ], [ :bean, :brew ] ]).each do |method, photos|
      brew = create_fresh_hero_brew(method:)
      bean_photo = attach_large_hero_photo(brew.bean) if photos.include?(:bean)
      brew_photo = attach_large_hero_photo(brew) if photos.include?(:brew)
      brew.bean.set_primary_photo!(bean_photo) if bean_photo
      brew.set_primary_photo!(brew_photo) if brew_photo

      get brew_path(brew)

      assert_response :success, "#{method} #{photos.inspect}"
      assert_select "[data-testid=brew-hero-backdrop][aria-hidden=true].pointer-events-none.grid.grid-cols-2", 1
      assert_select "[data-testid=brew-hero-bean-half].bg-black", 1
      assert_select "[data-testid=brew-hero-brew-half].bg-black", 1
      assert_select "[data-testid=brew-hero-overlay].relative.z-10", 1
      assert_select "[data-testid=brew-bean-photo-frame]", count: 0

      if bean_photo
        assert_select "img[data-testid=brew-hero-bean-image][src=?].object-contain", media_attachment_path(bean_photo, variant: :hero)
      else
        assert_select "img[data-testid=brew-hero-bean-image]", count: 0
      end

      if brew_photo
        assert_select "img[data-testid=brew-hero-brew-image][src=?].object-cover", media_attachment_path(brew_photo, variant: :hero)
      else
        assert_select "img[data-testid=brew-hero-brew-image]", count: 0
      end

      assert_select "[data-testid=brew-hero-center-blend]", count: (bean_photo && brew_photo ? 1 : 0)

      if method == "espresso"
        assert_select "[data-testid=brew-chart-grid]", 1
        assert_select "[data-testid=brew-hero-upper] [data-testid=brew-chart-grid]", count: 0
      else
        assert_select "[data-testid=brew-chart-grid]", count: 0
        assert_select "[data-testid=brew-equipment-footer]", 1
        assert_select "[data-testid=brew-hero-upper] [data-testid=brew-equipment-footer]", count: 0
      end
    end
  end

  test "hero history renders the shared two-photo backdrop" do
    brew = brews(:morning_espresso)
    bean_photo = attach_large_hero_photo(brew.bean)
    brew_photo = attach_large_hero_photo(brew)
    brew.bean.set_primary_photo!(bean_photo)
    brew.set_primary_photo!(brew_photo)
    sign_in_as(users(:one))

    get coffees_path(view: "hero", filter: "brews")

    assert_response :success
    assert_select "[data-testid=brew-history-hero-card] [data-testid=brew-hero-backdrop]", minimum: 1
    assert_select "[data-testid=brew-history-hero-card] img[data-testid=brew-hero-bean-image][src=?]", media_attachment_path(bean_photo, variant: :hero)
    assert_select "[data-testid=brew-history-hero-card] img[data-testid=brew-hero-brew-image][src=?]", media_attachment_path(brew_photo, variant: :hero)
  end

  test "hero brew card shows tiny primary equipment photos" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    grinder_photo = attach_photo(brew.grinder)
    machine_photo = attach_photo(brew.machine)
    brew.grinder.set_primary_photo!(grinder_photo)
    brew.machine.set_primary_photo!(machine_photo)

    get brew_path(brew)

    assert_response :success
    assert_select "img[data-testid=brew-grinder-photo][src=?]", media_attachment_path(grinder_photo, variant: :thumbnail)
    assert_select "img[data-testid=brew-machine-photo][src=?]", media_attachment_path(machine_photo, variant: :thumbnail)
  end

  test "quick drip detail shows estimate calculation and brewer" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      taste_balance: "sour"
    )
    sign_in_as(users(:one))

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-detail-brewer] a[href=?]", equipment_path(equipment(:household_brewer)), text: "Moccamaster"
    assert_select "[data-testid=brew-detail-machine-cups]", "6"
    assert_select "[data-testid=brew-detail-estimate]", "6 spoons x 5g = ~30g"
    assert_select "[data-testid=brew-detail-taste]", "Weak"
  end

  test "quick drip hero card renders metric first batch facts without espresso chart" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      taste_balance: "neutral",
      rating: 4,
      total_time_seconds: 320
    )
    sign_in_as(users(:one))

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-hero-card][data-method=quick_drip]"
    assert_select "[data-testid=brew-recipient-title-row].min-w-0.max-w-full"
    assert_select "[data-testid=brew-title-block].min-w-0.max-w-full.flex-1.overflow-hidden"
    assert_select "[data-testid=brew-recipient-byline].min-w-0.max-w-full.overflow-hidden"
    assert_select "[data-testid=brew-recipient-badge].min-w-0.max-w-full.overflow-hidden"
    assert_select "[data-testid=brew-method]", "Quick Drip"
    assert_select "[data-testid=quick-drip-machine-cups]", "6"
    assert_select "[data-testid=quick-drip-coffee]", "6 spoons"
    assert_select "[data-testid=quick-drip-consumed]", "~30g"
    assert_select "[data-testid=quick-drip-duration]", "320s"
    assert_select "[data-testid=brew-chart-grid]", count: 0
    assert_select "[data-testid=brew-retention-card]", count: 0
  end

  test "measured quick drip hero card renders grams as coffee amount" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 32,
      taste_balance: "neutral",
      rating: 4
    )
    sign_in_as(users(:one))

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=quick-drip-coffee]", "32g"
    assert_select "[data-testid=quick-drip-consumed]", "32g"
    assert_select "[data-testid=quick-drip-coffee]", text: /Unknown/, count: 0
  end

  test "show renders unknown username when display name is blank" do
    sign_in_as(users(:one))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "[data-testid=brew-byline]", "Logged by unknown username for themself"
    assert_select "body", text: /one@example.com/, count: 0
  end

  test "private brew cards present self member and guest recipients consistently" do
    logger = users(:one)
    recipient = users(:two)
    logger.update!(display_name: "Jens")
    recipient.update!(display_name: "Petra")
    brew = brews(:morning_espresso)
    sign_in_as(logger)

    get brew_path(brew)
    assert_select "[data-testid=brew-card-header] [data-testid=brew-recipient-badge]", count: 0
    assert_select "[data-testid=brew-recipient-title-row].min-w-0.max-w-full"
    assert_select "[data-testid=brew-title-block].min-w-0.max-w-full.flex-1.overflow-hidden"
    assert_select "[data-testid=brew-recipient-byline].min-w-0.max-w-full.overflow-hidden"
    assert_select "[data-testid=brew-recipient-badge].min-w-0.max-w-full.overflow-hidden"
    assert_select "[data-testid=brew-recipient-badge][class*=?]", "bg-sky-100" do
      assert_select "span", "For me"
    end
    assert_select "[data-testid=brew-recipient-badge] svg[data-symbol=person]"
    assert_select "[data-testid=brew-recipient-byline].text-stone-200", "Logged by Jens for themself"
    assert_select "[data-testid=brew-detail-recipient]", "For me"

    brew.update!(recipient_kind: "household_member", recipient_user: recipient)
    get brew_path(brew)
    assert_select "[data-testid=brew-recipient-badge][class*=?]", "bg-orange-100" do
      assert_select "span", "For Petra"
    end
    assert_select "[data-testid=brew-recipient-badge] svg[data-symbol=home]"
    assert_select "[data-testid=brew-recipient-byline]", "Logged by Jens for Petra"
    assert_select "[data-testid=brew-detail-recipient]", "For Petra"

    brew.update!(recipient_kind: "guest", recipient_name: "A very long private guest recipient name")
    get brew_path(brew)
    assert_select "[data-testid=brew-recipient-badge][class*=?]", "bg-emerald-100" do
      assert_select "span", "For A very long private guest recipient name"
    end
    assert_select "[data-testid=brew-recipient-badge] svg[data-symbol=groups]"
    assert_select "[data-testid=brew-recipient-badge] svg[data-symbol=groups] path[d=?]", ApplicationHelper::MATERIAL_SYMBOL_PATHS.fetch("groups")
    assert_select "[data-testid=brew-recipient-byline] .min-w-0", minimum: 1

    brew.update!(recipient_kind: "guest", recipient_name: nil, cup_style: "Cortado")
    get brews_path
    assert_select "[data-testid=brew-history-compact-card] [data-testid=brew-recipient-byline].text-rn-muted", "Logged by Jens for a guest"
    assert_select "[data-testid=brew-history-compact-card] [data-testid=brew-recipient-badge][class*=?]", "bg-emerald-100" do
      assert_select "span", "For a guest"
    end
    assert_select "[data-testid=brew-history-compact-card] [data-testid=brew-cup-badge]", "Cup: Cortado"
    assert_select "[data-testid=brew-recipient-badge] [data-testid=brew-cup-badge]", count: 0
  end

  test "private recipient cards suppress former recipient and former logger avatars independently" do
    logger = users(:one)
    recipient = users(:two)
    logger.update!(display_name: "Jens")
    recipient.update!(display_name: "Petra")
    brew = brews(:morning_espresso)
    attach_named_photo(logger, :avatar, filename: "jens.jpg")
    attach_named_photo(recipient, :avatar, filename: "petra.jpg")
    brew.update!(recipient_kind: "household_member", recipient_user: recipient)
    sign_in_as(logger)

    memberships(:member).destroy!
    get brew_path(brew)
    assert_select "[data-testid=brew-recipient-badge]", "For Petra"
    assert_select "img[data-testid=brew-recipient-avatar]", count: 0
    assert_select "img[data-testid=brew-logger-avatar]", count: 1

    Membership.create!(workspace: workspaces(:household), user: recipient, role: "member")
    memberships(:owner).destroy!
    recipient.update!(active_workspace: workspaces(:household))
    sign_in_as(recipient)
    get brew_path(brew)
    assert_select "[data-testid=brew-recipient-badge]", "For Petra"
    assert_select "img[data-testid=brew-logger-avatar]", count: 0
    assert_select "img[data-testid=brew-recipient-avatar]", count: 1
  end

  test "show omits bean processing from private hero card descriptor" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.bean.update!(origin: "Colombia", process: "Washed", roast_level: "Light")

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-title-block]", text: /Colombia/
    assert_select "[data-testid=brew-title-block]", text: /Light/
    assert_select "[data-testid=brew-title-block]", text: /Washed/, count: 0
  end

  test "writer sees brew correction actions" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    get brew_path(brew)

    assert_response :success
    header = Nokogiri::HTML(response.body).at_css("[data-testid='brew-detail-header-controls']")
    assert_not_includes header["class"].to_s, "flex-col"
    actions = Nokogiri::HTML(response.body).at_css("[data-testid='brew-detail-actions']")
    assert_not_includes actions["class"].to_s, "overflow-x-auto"
    assert_select "[data-testid=brew-detail-actions] svg.material-symbol", minimum: 1
    assert_select "[data-testid=?][href=?]",
      "brew-edit-link-#{brew.id}-mobile",
      edit_brew_path(brew)
    assert_select "[data-testid=brew-detail-actions-more]"
    assert_select "[data-testid=brew-detail-actions-menu] a[href=?]", new_brew_path(repeat_brew_id: brew.id), text: I18n.t("brews.show.repeat")
    assert_select "[data-testid=brew-detail-actions-menu] a[href=?]", new_recipe_path(source_brew_id: brew.id), text: I18n.t("brews.show.save_as_recipe")
    assert_select "[data-testid=brew-detail-actions] form[action=?]", brew_path(brew), count: 0
    assert_select "[data-testid=brew-danger-zone] form[action=?]", brew_path(brew)
    assert_appears_before "data-testid=\"brew-log-details\"", "data-testid=\"brew-danger-zone\""
  end

  test "writer does not see save as recipe action on quick drip brew" do
    user = users(:one)
    brew = create_spoon_estimated_quick_drip_brew_for(user)
    sign_in_as(user)

    get brew_path(brew)

    assert_response :success
    assert_select "a[href=?]", new_brew_path(repeat_brew_id: brew.id), text: I18n.t("brews.show.repeat")
    assert_select "a[href=?]", new_recipe_path(source_brew_id: brew.id), text: I18n.t("brews.show.save_as_recipe"), count: 0
  end

  test "writer sees public share action on brew detail" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    get brew_path(brew)

    assert_response :success
    assert_select "a[href=?]", new_brew_public_brew_share_path(brew), text: I18n.t("brews.show.share_publicly")
  end

  test "quick drip public sharing is not exposed in v1" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )
    sign_in_as(users(:one))

    get brew_path(brew)

    assert_response :success
    assert_select "a[href=?]", new_brew_public_brew_share_path(brew), count: 0
  end

  test "writer sees edit public share action when brew already has a share" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.create_public_brew_share!(
      workspace: brew.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: false,
      title: "Shared shot",
      selected_photo_attachment_ids: [],
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Shared shot",
        selected_photo_attachment_ids: []
      ).call
    )

    get brew_path(brew)

    assert_response :success
    assert_select "a[href=?]", edit_brew_public_brew_share_path(brew), text: I18n.t("brews.show.share_publicly")
    assert_select "[data-testid=?]", "brew-native-share-button-#{brew.id}", count: 0
  end

  test "writer sees native share action when public share is enabled" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    share = create_public_brew_share_for(brew, enabled: true)

    get brew_path(brew)

    assert_response :success
    actions = Nokogiri::HTML(response.body).at_css("[data-testid='brew-detail-actions']")
    assert_not_includes actions["class"].to_s, "overflow-x-auto"
    assert_select "[data-testid=?][data-native-share-url-value=?]",
      "brew-native-share-button-#{brew.id}",
      public_brew_page_url(share.token)
    assert_select "[data-testid=?] svg.material-symbol[data-symbol=ios_share][aria-hidden=true]", "brew-native-share-button-#{brew.id}"
    assert_appears_before "brew-native-share-button-#{brew.id}", edit_brew_public_brew_share_path(brew)
  end

  test "writer sees explicit taste correction form on brew detail" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-taste-correction]"
    assert_select "form[action=?][method=post]", taste_brew_path(brew)
    assert_select "input[name=_method][value=patch]"
    assert_select "select[name=?]", "brew[taste_balance]", count: 0
    assert_select "[data-testid=brew-taste-balance-options]"
    assert_select "input[type=radio][name=?]", "brew[taste_balance]", count: Brew.taste_balances.size
    assert_select "[data-testid=brew-taste-unknown-choice] input[type=radio][name=?][value=?]",
      "brew[taste_balance]",
      "unknown"
    assert_select "[data-testid=brew-taste-balance-scale] input[type=radio][name=?]", "brew[taste_balance]", count: Brew.taste_balances.size - 1
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[taste_balance]", brew.taste_balance
    assert_select ".rn-choice-label", text: brew.taste_balance.humanize
    assert_select "input[type=number][name=?]", "brew[rating]", count: 0
    assert_select "[data-testid=brew-rating-options]"
    assert_select "input[type=radio][name=?]", "brew[rating]", count: 6
    assert_select "input[type=radio][name=?][value=?][checked]", "brew[rating]", brew.rating.to_s
    assert_select "input[type=submit][value=?]", I18n.t("brews.show.save_taste")
  end

  test "brew detail identifies saved brew screen" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    get brew_path(brew)

    assert_response :success
    assert_select "h1", I18n.t("brews.show.saved_brew")
    assert_select "[data-testid=brew-detail-screen-label]", I18n.t("brews.show.detail_screen_label")
  end

  test "writer sees the shared recipient control once on brew detail" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-serving-correction]"
    assert_select "form[action=?][method=post]", serving_brew_path(brew)
    assert_select "input[name=_method][value=patch]"
    assert_select "[data-testid=brew-recipient-fields]", count: 1
    assert_select "input[type=radio][name=?][value=self][checked]", "brew[recipient_selection]"
    assert_select "input[type=text][name=?][list=brew_recipient_name_suggestions]", "brew[recipient_name]"
    assert_select "input[type=text][name=?][list=brew_cup_style_suggestions]", "brew[cup_style]", count: 1
    assert_select "input[type=submit][value=?]", I18n.t("brews.show.save_serving")
  end

  test "focused correction resolves a member and cannot change inventory or unrelated fields" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    weight = brew.bean_weight_grams
    adjustment = brew.inventory_adjustment.delta_grams
    event = nil
    assert_difference(-> { ActivityEvent.count }, 1) do
      event = assert_activity_event(
        action: "brew.serving_changed",
        workspace: workspaces(:household),
        actor: users(:one),
        subject: brew
      ) do
        patch serving_brew_path(brew), params: { brew: {
          recipient_selection: "member:#{users(:two).id}", recipient_name: "Ignored", cup_style: "Cortado",
          bean_weight_grams: "40", notes: "Ignored"
        } }
      end
    end
    assert_redirected_to brew_path(brew)
    assert_equal "brew.serving_changed", event.action
    brew.reload
    assert_predicate brew, :recipient_household_member?
    assert_equal users(:two), brew.recipient_user
    assert_nil brew.recipient_name
    assert_equal "Cortado", brew.cup_style
    assert_equal weight, brew.bean_weight_grams
    assert_equal adjustment, brew.inventory_adjustment.reload.delta_grams
  end

  test "explicit guest selection retains an invalid typed name for redisplay" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    assert_no_difference(-> { ActivityEvent.count }) do
      patch serving_brew_path(brew), params: { brew: { recipient_selection: "guest", recipient_name: "A" * 121 } }
    end
    assert_response :unprocessable_entity
    assert_select "input[name=?][value=?]", "brew[recipient_name]", "A" * 121
    assert_select "input[name=?][value=guest][checked]", "brew[recipient_selection]"
    assert_predicate brew.reload, :recipient_self?
  end

  test "explicit self selection clears a previous guest name without javascript" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Anna")

    patch serving_brew_path(brew), params: {
      brew: { recipient_selection: "self", recipient_name: "Anna", cup_style: "Espresso" }
    }

    assert_redirected_to brew_path(brew)
    assert_predicate brew.reload, :recipient_self?
    assert_nil brew.recipient_name
  end

  test "a newly typed name infers guest from the default self radio without javascript" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    patch serving_brew_path(brew), params: {
      brew: { recipient_selection: "self", recipient_name: "Anna", cup_style: "Latte" }
    }

    assert_redirected_to brew_path(brew)
    assert_predicate brew.reload, :recipient_guest?
    assert_equal "Anna", brew.recipient_name
  end

  test "explicit former-member selection wins over a submitted name without javascript" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    former_member = users(:two)
    brew.update!(recipient_kind: "household_member", recipient_user: former_member)
    memberships(:member).destroy!

    patch serving_brew_path(brew), params: {
      brew: { recipient_selection: "existing_recipient", recipient_name: "Anna" }
    }

    assert_redirected_to brew_path(brew)
    assert_predicate brew.reload, :recipient_household_member?
    assert_equal former_member, brew.recipient_user
    assert_nil brew.recipient_name
  end

  test "foreign member token is rejected without creating a brew or consuming inventory" do
    outsider = User.create!(email_address: "foreign-recipient@example.test", password: "password")
    bean = beans(:open_household)
    remaining = bean.remaining_grams
    sign_in_as(users(:one))
    assert_no_difference("Brew.count") do
      post brews_path, params: { brew: {
        method: "espresso", bean_id: bean.id, bean_weight_grams: "18",
        recipient_selection: "member:#{outsider.id}"
      } }
    end
    assert_response :not_found
    assert_equal remaining, bean.reload.remaining_grams
  end

  test "activity failure rolls back serving and both public snapshot refreshes" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew_share = create_public_brew_share_for(brew, enabled: true)
    bean_share = create_public_bean_share_for(brew.bean)
    original = [ brew.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
    original_brew_snapshot = brew_share.snapshot.deep_dup
    original_bean_snapshot = bean_share.snapshot.deep_dup
    failure = ->(**) { raise ActiveRecord::RecordInvalid.new(ActivityEvent.new) }

    assert_no_difference -> { ActivityEvent.where(action: "brew.serving_changed", subject: brew).count } do
      with_stubbed_singleton_method(Activity::Emitter, :record!, failure) do
        patch serving_brew_path(brew), params: {
          brew: { recipient_selection: "member:#{users(:two).id}", cup_style: "Cortado" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_equal original, [ brew.reload.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
    assert_equal original_brew_snapshot, brew_share.reload.snapshot
    assert_equal original_bean_snapshot, bean_share.reload.snapshot
  end

  test "snapshot refresh failure rolls back serving earlier refreshes and activity" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew_share = create_public_brew_share_for(brew, enabled: true)
    create_public_bean_share_for(brew.bean)
    original = [ brew.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
    original_brew_snapshot = brew_share.snapshot.deep_dup
    failure = ->(*) { raise ActiveRecord::RecordInvalid.new(PublicBeanShare.new) }

    assert_no_difference -> { ActivityEvent.where(action: "brew.serving_changed", subject: brew).count } do
      with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_for, failure) do
        patch serving_brew_path(brew), params: {
          brew: { recipient_selection: "guest", recipient_name: "Anna", cup_style: "Latte" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_equal original, [ brew.reload.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
    assert_equal original_brew_snapshot, brew_share.reload.snapshot
  end

  test "viewer cannot see or submit serving correction" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    brew = brews(:morning_espresso)

    get brew_path(brew)
    assert_response :success
    assert_select "[data-testid=brew-serving-correction]", count: 0

    patch serving_brew_path(brew), params: { brew: { recipient_selection: "guest", recipient_name: "Anna", cup_style: "Latte" } }
    assert_redirected_to root_path
    assert_predicate brew.reload, :recipient_self?
  end

  test "serving update is scoped to active workspace" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    other_brew = brews(:other_workspace_brew)

    patch serving_brew_path(other_brew), params: {
      brew: { recipient_selection: "guest", recipient_name: "Anna", cup_style: "Latte" }
    }

    assert_response :not_found
    assert_predicate other_brew.reload, :recipient_self?
  end

  test "writer can update only brew taste fields from detail page" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    original_weight = brew.bean_weight_grams
    original_adjustment = brew.inventory_adjustment.delta_grams

    assert_activity_event(action: "brew.taste_changed", workspace: brew.workspace, actor: users(:one), subject: brew) do
      patch taste_brew_path(brew), params: {
        brew: {
          taste_balance: "bitter",
          rating: "5",
          bean_weight_grams: "30",
          notes: "Ignored from taste correction"
        }
      }
    end

    assert_redirected_to brew_path(brew)
    brew.reload
    assert_equal "bitter", brew.taste_balance
    assert_equal 5, brew.rating
    assert_equal original_weight, brew.bean_weight_grams
    assert_not_equal "Ignored from taste correction", brew.notes
    assert_equal original_adjustment, brew.inventory_adjustment.reload.delta_grams
  end

  test "invalid taste correction re-renders brew detail" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    patch taste_brew_path(brew), params: { brew: { taste_balance: "neutral", rating: "6" } }

    assert_response :unprocessable_entity
    assert_select "[data-testid=brew-taste-correction]"
    assert_equal brews(:morning_espresso).rating, brew.reload.rating
  end

  test "viewer cannot see or submit taste correction" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    brew = brews(:morning_espresso)

    get brew_path(brew)
    assert_response :success
    assert_select "[data-testid=brew-taste-correction]", count: 0

    patch taste_brew_path(brew), params: { brew: { rating: "5", taste_balance: "bitter" } }
    assert_redirected_to root_path
    assert_not_equal 5, brew.reload.rating
  end

  test "writer can edit brew" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "h1", I18n.t("brews.edit.title")
    assert_select "form[action=?]", brew_path(brews(:morning_espresso))
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.0"
  end

  test "edit marks brew when public share is enabled" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    create_public_brew_share_for(brew, enabled: true)

    get edit_brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-edit-shared-marker]", I18n.t("brews.shared_marker")
  end

  test "edit does not mark brew when public share is disabled" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    create_public_brew_share_for(brew, enabled: false)

    get edit_brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-edit-shared-marker]", count: 0
  end

  test "writer can update brew and inventory" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    assert_activity_event(action: "brew.updated", workspace: brew.workspace, actor: users(:one), subject: brew) do
      patch brew_path(brew), params: {
        brew: {
          bean_id: beans(:open_household).id,
          grinder_id: equipment(:household_grinder).id,
          machine_id: equipment(:household_machine).id,
          bean_weight_grams: "20.0",
          ground_weight_grams: "19.8",
          dose_grams: "19.5",
          beverage_grams: "44",
          taste_balance: "neutral",
          preparation_tool_ids: [ preparation_tools(:puck_screen).id ]
        }
      }
    end

    assert_redirected_to brew_path(brew)
    assert_equal 148.to_d, beans(:open_household).reload.remaining_grams
    assert_equal(-20.to_d, brew.inventory_adjustment.reload.delta_grams)
    assert_equal [ "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  test "writer can delete brew and reverse inventory" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    brew.update!(public_note: "Deleted brew public note")
    share = create_public_bean_share_for(brew.bean)

    assert_difference -> { Brew.count }, -1 do
      assert_activity_event(action: "brew.deleted", workspace: brew.workspace, actor: users(:one)) do
        delete brew_path(brew)
      end
    end

    assert_redirected_to root_path
    assert_equal 168.to_d, beans(:open_household).reload.remaining_grams
    assert_not_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "Deleted brew public note"
  end

  test "viewer cannot edit update or delete brew" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    brew = brews(:morning_espresso)

    get edit_brew_path(brew)
    assert_redirected_to root_path

    assert_no_changes -> { brew.reload.bean_weight_grams } do
      patch brew_path(brew), params: { brew: { bean_weight_grams: "20" } }
    end
    assert_redirected_to root_path

    assert_no_difference -> { Brew.count } do
      delete brew_path(brew)
    end
    assert_redirected_to root_path
  end

  test "edit is scoped to active workspace" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:other_workspace_brew))

    assert_response :not_found
  end

  test "viewer cannot create brew" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).brews.count } do
      post brews_path, params: { brew: { bean_id: beans(:open_household).id, bean_weight_grams: "18" } }
    end

    assert_redirected_to root_path
  end

  test "index shows workspace coffees newest first in compact view by default" do
    older = brews(:morning_espresso)
    older.update!(occurred_at: Time.zone.local(2026, 5, 30, 8, 0, 0))
    create_public_brew_share_for(older, enabled: true)
    newest = workspaces(:household).brews.create!(
      user: users(:one),
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0),
      bean_weight_grams: 19,
      dose_grams: 18.5,
      beverage_grams: 46,
      total_time_seconds: 30,
      grind_setting: "13",
      taste_balance: "neutral",
      rating: 5
    )
    create_public_brew_share_for(newest, enabled: false)
    external = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Americano",
      place_name: "Corner Cafe",
      occurred_at: Time.zone.local(2026, 6, 1, 10, 0, 0),
      acidity_balance: "balanced",
      intensity: "strong",
      rating: 4
    )

    sign_in_as(users(:one))
    get coffees_path

    assert_response :success
    assert_select "h1", I18n.t("brews.index.title")
    assert_select "[data-testid=coffee-filter-all][aria-current=page]"
    assert_select "[data-testid=coffee-filter-brews]"
    assert_select "[data-testid=coffee-filter-external]"
    assert_select "[data-testid=brew-history-compact-card].overflow-hidden", count: 2
    assert_select "a[href=?][data-testid=external-coffee-card]", external_coffee_path(external), text: /Americano/
    assert_select "[data-testid=brew-compact-card][data-method=espresso].overflow-hidden", count: 2
    assert_select "[data-testid=brew-history-hero-card]", count: 0
    assert_select "a[href=?]", brew_path(newest), text: /#{newest.bean.name}/
    assert_select "a[href=?]", brew_path(older), text: /#{older.bean.name}/
    assert_select "[data-testid=?]", "brew-history-shared-marker-#{older.id}", I18n.t("brews.shared_marker")
    assert_select "[data-testid=?]", "brew-history-shared-marker-#{newest.id}", count: 0
    assert_select "[data-testid=?] svg.material-symbol[data-symbol=ios_share][aria-hidden=true]", "brew-native-share-button-#{older.id}"
    assert_select "[data-testid=?]", "brew-native-share-button-#{newest.id}", count: 0
    assert_select "[data-testid=?]", "brew-history-compact-card-link-#{older.id}"
    assert_select "a[href=?]", brew_path(brews(:other_workspace_brew)), count: 0
    assert_appears_before external.drink_type, newest.bean.name
    assert_appears_before newest.bean.name, older.bean.name

    get coffees_path, params: { filter: "brews" }

    assert_response :success
    assert_select "[data-testid=coffee-filter-brews][aria-current=page]"
    assert_select "[data-testid=brew-history-compact-card].overflow-hidden", count: 2
    assert_select "a[href=?][data-testid=external-coffee-card]", external_coffee_path(external), count: 0

    get coffees_path, params: { filter: "external" }

    assert_response :success
    assert_select "[data-testid=coffee-filter-external][aria-current=page]"
    assert_select "[data-testid=brew-history-compact-card].overflow-hidden", count: 0
    assert_select "a[href=?][data-testid=external-coffee-card]", external_coffee_path(external), text: /Americano/
  end

  test "compact brew card is method aware for quick drip" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )
    sign_in_as(users(:one))

    get brews_path

    assert_response :success
    assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /Quick Drip/
    assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /6 cups/
    assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /Moccamaster/
  end

  test "compact brew card shows measured quick drip grams" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 32,
      taste_balance: "neutral",
      rating: 4
    )
    sign_in_as(users(:one))

    get brews_path

    assert_response :success
    assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /32g/
    assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /Unknown/, count: 0
  end

  test "index can render hero cards" do
    external = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Flat White",
      place_name: "Neighborhood Coffee",
      occurred_at: Time.current + 5.minutes
    )
    sign_in_as(users(:one))

    get coffees_path, params: { view: "hero" }

    assert_response :success
    assert_select "[data-testid=brew-history-hero-card]", count: 1
    assert_select "[data-testid=external-coffee-history-hero-card] a[href=?]", external_coffee_path(external)
    assert_select "[data-testid=external-coffee-hero-card]", text: /Flat White/
    assert_select "[data-testid=brew-history-compact-card]", count: 0
    assert_select "[data-testid=brew-history-hero-card] a[href=?]", brew_path(brews(:morning_espresso))
  end

  test "index paginates coffees and preserves selected view" do
    workspace = workspaces(:household)
    21.times do |index|
      workspace.brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        occurred_at: Time.zone.local(2026, 6, 1, 12, 0, 0) - index.minutes,
        bean_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 45
      )
    end
    sign_in_as(users(:one))

    get coffees_path, params: { view: "hero" }

    assert_response :success
    assert_select "[data-testid=history-next-page][href=?]", coffees_path(view: "hero", page: 2)

    get coffees_path, params: { view: "hero", page: 2 }

    assert_response :success
    assert_select "[data-testid=history-previous-page][href=?]", coffees_path(view: "hero", page: 1)
  end

  test "viewer can read brew history" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get brews_path

    assert_response :success
    assert_select "h1", I18n.t("brews.index.title")
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end

    def create_public_brew_share_for(brew, enabled:)
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled:,
        title: "Shared shot",
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def create_public_bean_share_for(bean)
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def create_latest_quick_drip_brew_for(user)
      workspaces(:household).brews.create!(
        user:,
        bean: beans(:second_open_household),
        brewer: equipment(:household_brewer),
        method: "quick_drip",
        occurred_at: Time.current + 1.minute,
        machine_cups: 6,
        bean_weight_grams: 30,
        beverage_grams: 900,
        total_time_seconds: 320,
        taste_balance: "neutral"
      )
    end

    def create_spoon_estimated_quick_drip_brew_for(user)
      workspaces(:household).brews.create!(
        user:,
        bean: beans(:second_open_household),
        brewer: equipment(:household_brewer),
        grinder: equipment(:household_grinder),
        method: "quick_drip",
        occurred_at: Time.current + 1.minute,
        machine_cups: 6.5,
        coffee_spoons: 5.5,
        grams_per_coffee_spoon: 4.25,
        beverage_grams: 900,
        total_time_seconds: 320,
        grind_setting: "medium",
        taste_balance: "bitter",
        rating: 5,
        notes: "Do not copy."
      )
    end

    def create_fresh_hero_brew(method:)
      bean = workspaces(:household).beans.create!(
        name: "Hero #{method} #{SecureRandom.hex(4)}",
        bag_size_grams: 250,
        remaining_grams: 200,
        opened_on: Date.current,
        roast_type: "espresso",
        blend_type: "unknown",
        grind_state: "whole_bean"
      )
      attributes = {
        workspace: workspaces(:household),
        user: users(:one),
        bean:,
        method:,
        bean_weight_grams: 18,
        taste_balance: "neutral"
      }
      attributes.merge!(
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        dose_grams: 18,
        beverage_grams: 40,
        total_time_seconds: 28
      ) if method == "espresso"
      attributes.merge!(
        brewer: equipment(:household_brewer),
        machine_cups: 6
      ) if method == "quick_drip"
      workspaces(:household).brews.create!(attributes)
    end

    def attach_large_hero_photo(record)
      File.open(Rails.root.join("app/assets/images/brand/logo_mark_transparent.png")) do |file|
        record.photos.attach(io: file, filename: "hero-photo.png", content_type: "image/png")
      end
      record.photos.attachments.last
    end
end
