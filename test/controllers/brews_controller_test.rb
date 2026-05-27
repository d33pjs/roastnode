require "test_helper"

class BrewsControllerTest < ActionDispatch::IntegrationTest
  test "new redirects to new bean when workspace has no open beans" do
    workspaces(:household).beans.update_all(remaining_grams: 0, archived_at: Time.current)
    sign_in_as(users(:one))

    get new_brew_path

    assert_redirected_to new_bean_path
  end

  test "new defaults to current user's last active bean" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "h1", I18n.t("brews.new.title")
    assert_select "option[selected][value=?]", beans(:open_household).id.to_s
    assert_select "option[selected][value=?]", equipment(:household_grinder).id.to_s
    assert_select "option[selected][value=?]", equipment(:household_machine).id.to_s
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[ground_weight_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[dose_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "40.0", count: 0
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12"
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", "93.0"
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "28", count: 0
    assert_select "input[name=?][value=?]", "brew[preinfusion_seconds]", "5"
    assert_select "input[name=?][value=?]", "brew[first_drip_seconds]", "8", count: 0
    assert_select "input[name=?][value=?]", "brew[rating]", "4", count: 0
    assert_select "textarea[name=?]", "brew[notes]", text: ""
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:puck_screen).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:other_workspace_tool).id.to_s, count: 0
    assert_select "input[type=file][name=?][multiple=multiple]", "brew[photos][]"
  end

  test "new does not offer archived equipment" do
    archived_grinder = equipment(:household_grinder)
    archived_machine = equipment(:household_machine)
    archived_grinder.update!(archived_at: Time.current)
    archived_machine.update!(archived_at: Time.current)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "select[name=?] option[value=?]", "brew[grinder_id]", archived_grinder.id.to_s, count: 0
    assert_select "select[name=?] option[value=?]", "brew[machine_id]", archived_machine.id.to_s, count: 0
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
      "roastnode:brew:new:#{workspace.id}:#{user.id}"
    assert_select "[data-brew-draft-target=?].hidden", "notice"
    assert_select "button[type=button][data-action=?]", "brew-draft#discard", text: I18n.t("brews.form.discard_draft")
  end

  test "edit does not wire browser draft recovery" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "form[data-controller~=?]", "brew-draft", count: 0
  end

  test "new falls back to first open bean when last bean is closed" do
    beans(:open_household).update!(archived_at: Time.current, remaining_grams: 0)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "option[selected][value=?]", beans(:second_open_household).id.to_s
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
    assert_select "option[value=?]", beans(:open_household).id.to_s, text: "Good Coffee - House Blend (opened 10.05.2026)"
    assert_select "option[value=?]", duplicate.id.to_s, text: "Good Coffee - House Blend (opened 20.05.2026)"
    assert_select "option[value=?]", beans(:second_open_household).id.to_s, text: "North Star - Morning Lot"
  end

  test "member can create espresso brew and consume selected bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:second_open_household)

    assert_difference -> { workspaces(:household).brews.count }, 1 do
      assert_difference -> { InventoryAdjustment.count }, 1 do
        assert_difference -> { BrewPreparationTool.count }, 2 do
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
              taste_balance: "neutral",
              rating: "4",
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

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 201.5.to_d, bean.reload.remaining_grams
    assert_equal [ "WDT", "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
    assert_equal 1, brew.photos.count
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

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(brews(:morning_espresso))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment)
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
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(bean_photo)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(grinder_photo)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(machine_photo)
    assert_select "img[data-testid=brew-related-photo][src=?]", media_attachment_path(tool_photo)
    assert_select "a[href=?]", download_media_attachment_path(tool_photo), text: I18n.t("shared.related_photo_group.download")
  end

  test "show renders compact hero brew card" do
    users(:one).update!(display_name: "Jens")
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    bean_photo = attach_photo(brew.bean)
    avatar = attach_named_photo(users(:one), :avatar, filename: "avatar.jpg")
    workspace_logo = attach_named_photo(workspaces(:household), :logo, filename: "workspace-logo.jpg")
    brew.update!(
      occurred_at: Time.zone.local(2026, 5, 26, 11, 22, 8),
      bean_weight_grams: 18.6,
      ground_weight_grams: 18.2,
      dose_grams: 18.2,
      beverage_grams: 45.0,
      grind_setting: "12",
      brew_temperature_celsius: 93.0,
      preinfusion_seconds: 6,
      first_drip_seconds: 8,
      total_time_seconds: 31,
      rating: 4,
      taste_balance: "neutral",
      channeling: true,
      notes: "Balanced morning shot."
    )

    get brew_path(brew)

    assert_response :success
    assert_select "[data-testid=brew-hero-card]"
    assert_select "[data-testid=brew-card-header] img[data-testid=brew-card-brand-mark][alt=?]", ""
    assert_select "[data-testid=brew-card-header].flex-nowrap"
    assert_select "[data-testid=brew-timestamp].text-\\[0\\.58rem\\]"
    assert_select "[data-testid=brew-workspace].truncate"
    assert_select "[data-testid=brew-workspace] img[data-testid=brew-workspace-logo][src=?]", media_attachment_path(workspace_logo)
    assert_select "img[data-testid=brew-card-brand-mark][src*=?]", "logo_mark_transparent"
    assert_select "[data-testid=brew-title-block] + [data-testid=brew-bean-photo-frame] img[data-testid=brew-bean-photo][src=?]", media_attachment_path(bean_photo)
    assert_select "img[data-testid=brew-bean-photo][src=?]", media_attachment_path(bean_photo)
    assert_select "[data-testid=brew-bean-link]", count: 0
    assert_select "[data-testid=brew-timestamp]", "26.05.2026 11:22:08"
    assert_select "[data-testid=brew-workspace]", workspaces(:household).name
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "[data-testid=brew-byline]", "Logged by Jens"
    assert_select "[data-testid=brew-byline] img[data-testid=brew-user-avatar][src=?]", media_attachment_path(avatar)
    assert_select "[data-testid=brew-metrics].grid-cols-3"
    assert_select "[data-testid=brew-dose]", "18.2 g"
    assert_select "[data-testid=brew-beverage]", count: 0
    assert_select "[data-testid=brew-ratio-main]", "1:2,47"
    assert_select "[data-testid=brew-ratio-time]", "in 31s"
    assert_select "[data-testid=brew-grind]", "12"
    assert_select "[data-testid=brew-retention-label] .sm\\:hidden", "Ret."
    assert_select "[data-testid=brew-retention-label] .hidden.sm\\:inline", "Retention"
    assert_select "[data-testid=brew-retention-card] [data-testid=brew-retention]", "0.4 g"
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
    assert_select "[data-testid=brew-axis-max]", "50 g"
    assert_select "[data-testid=brew-grinder-link]", count: 0
    assert_select "[data-testid=brew-machine-link]", count: 0
    assert_select "a[data-testid=brew-tool]", count: 0
    assert_select "[data-testid=brew-tool]", "WDT"
    assert_select "[data-testid=brew-log-details]"
    assert_select "[data-testid=brew-detail-bean] a[href=?]", bean_path(brew.bean), text: brew.bean.display_name
    assert_select "[data-testid=brew-detail-bean-weight]", "18.6 g"
    assert_select "[data-testid=brew-detail-ground-weight]", "18.2 g"
    assert_select "[data-testid=brew-detail-beverage]", "45 g"
    assert_select "[data-testid=brew-detail-channeling]", "Yes"
    assert_select "[data-testid=brew-detail-grinder] a[href=?]", equipment_path(brew.grinder), text: brew.grinder.name
    assert_select "[data-testid=brew-detail-machine] a[href=?]", equipment_path(brew.machine), text: brew.machine.name
    assert_select "a[data-testid=brew-detail-tool][href=?]", preparation_tool_path(preparation_tools(:wdt)), text: "WDT"
    assert_select "[data-testid=brew-detail-notes]", "Balanced morning shot."
  end

  test "hero brew card uses primary bean photo" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)
    first = attach_photo(brew.bean)
    primary = attach_photo(brew.bean)
    brew.bean.update!(primary_photo_attachment_id: primary.id)

    get brew_path(brew)

    assert_response :success
    assert_select "img[data-testid=brew-bean-photo][src=?]", media_attachment_path(primary)
    assert_select "img[data-testid=brew-bean-photo][src=?]", media_attachment_path(first), count: 0
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
    assert_select "img[data-testid=brew-grinder-photo][src=?]", media_attachment_path(grinder_photo)
    assert_select "img[data-testid=brew-machine-photo][src=?]", media_attachment_path(machine_photo)
  end

  test "show renders unknown username when display name is blank" do
    sign_in_as(users(:one))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "[data-testid=brew-byline]", "Logged by unknown username"
    assert_select "body", text: /one@example.com/, count: 0
  end

  test "writer sees brew correction actions" do
    sign_in_as(users(:one))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "a[href=?]", edit_brew_path(brews(:morning_espresso)), text: I18n.t("brews.show.edit")
    assert_select "form[action=?]", brew_path(brews(:morning_espresso))
  end

  test "writer can edit brew" do
    sign_in_as(users(:one))

    get edit_brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "h1", I18n.t("brews.edit.title")
    assert_select "form[action=?]", brew_path(brews(:morning_espresso))
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.0"
  end

  test "writer can update brew and inventory" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

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

    assert_redirected_to brew_path(brew)
    assert_equal 148.to_d, beans(:open_household).reload.remaining_grams
    assert_equal(-20.to_d, brew.inventory_adjustment.reload.delta_grams)
    assert_equal [ "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  test "writer can delete brew and reverse inventory" do
    sign_in_as(users(:one))
    brew = brews(:morning_espresso)

    assert_difference -> { Brew.count }, -1 do
      delete brew_path(brew)
    end

    assert_redirected_to root_path
    assert_equal 168.to_d, beans(:open_household).reload.remaining_grams
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
end
