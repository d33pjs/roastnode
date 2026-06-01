require "test_helper"

class ActivityControllerTest < ActionDispatch::IntegrationTest
  test "index shows workspace activity newest first" do
    workspace = workspaces(:household)
    adjustment = workspace.inventory_adjustments.create!(
      bean: beans(:open_household),
      user: users(:one),
      delta_grams: 12.5,
      reason: "manual",
      note: "Found extra beans.",
      occurred_at: Time.zone.local(2026, 6, 1, 10, 0, 0)
    )
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0))
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0))
    sign_in_as(users(:one))

    get activity_path

    assert_response :success
    assert_select "h1", I18n.t("activity.index.title")
    assert_select "[data-testid=activity-card]", minimum: 3
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "p", text: I18n.t("activity.index.adjustment", amount: "12,5", bean: adjustment.bean.name)
    assert_select "a[href=?]", brew_path(brews(:other_workspace_brew)), count: 0
    assert_appears_before "12,5", beans(:open_household).name
    assert_appears_before beans(:open_household).name, "Grinder cleaning"
  end

  test "index paginates activity" do
    workspace = workspaces(:household)
    21.times do |index|
      workspace.inventory_adjustments.create!(
        bean: beans(:open_household),
        user: users(:one),
        delta_grams: index + 1,
        reason: "manual",
        note: "Correction #{index}",
        occurred_at: Time.zone.local(2026, 6, 1, 12, 0, 0) - index.minutes
      )
    end
    sign_in_as(users(:one))

    get activity_path

    assert_response :success
    assert_select "[data-testid=history-next-page][href=?]", activity_path(page: 2)

    get activity_path, params: { page: 2 }

    assert_response :success
    assert_select "[data-testid=history-previous-page][href=?]", activity_path(page: 1)
  end

  test "viewer can read activity history" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get activity_path

    assert_response :success
    assert_select "h1", I18n.t("activity.index.title")
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end
end
