require "test_helper"

class ActivityControllerTest < ActionDispatch::IntegrationTest
  test "index shows workspace activity newest first" do
    sign_in_as(users(:one))

    get activity_path

    assert_response :success
    assert_select "h1", I18n.t("activity.index.title")
    assert_select "[data-testid=activity-card]", minimum: 3
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /Espresso with House Espresso/
    assert_select "a[href=?]", brew_path(brews(:other_workspace_brew)), count: 0
    assert_appears_before "Member invite", "Quick Drip with Filter Beans"
    assert_appears_before "Quick Drip with Filter Beans", "Espresso with House Espresso"
  end

  test "index paginates activity" do
    21.times do |index|
      Activity::Emitter.record!(
        action: "brew.updated", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), occurred_at: Time.zone.local(2026, 8, 21, 12) - index.minutes
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

  test "filters authorized ledger rows and preserves filters in pagination" do
    users(:one).update!(display_name: "Jens")
    21.times do |index|
      Activity::Emitter.record!(
        action: "brew.updated", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), occurred_at: Time.zone.local(2026, 8, 21, 12) - index.minutes
      )
    end
    sign_in_as(users(:one))

    get activity_path, params: {
      category: "coffee", actor: "user:#{users(:one).id}",
      start_date: "2026-08-21", end_date: "2026-08-21"
    }

    assert_response :success
    assert_select "[data-testid=activity-card]", count: 20
    assert_select "select[data-testid=activity-category] option[value=coffee][selected]"
    assert_select "[data-testid=activity-actor] option[value=?]", "user:#{users(:one).id}", text: "Jens"
    assert_select "label[for=category]", text: "Category"
    assert_select "label[for=actor]", text: "User"
    assert_select "label[for=start_date]", text: "Start date"
    assert_select "label[for=end_date]", text: "End date"
    assert_select "[data-testid=history-next-page][href*=?]", "category=coffee"
    assert_select "[data-testid=history-next-page][href*=?]", "actor=user%3A#{users(:one).id}"
  end

  test "viewer does not receive restricted cards and anonymous public reads do not write ledger rows" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))

    get activity_path
    assert_response :success
    assert_select "[data-visibility=workspace_admin]", count: 0

    share = PublicBrewShare.create!(
      workspace: workspaces(:household), brew: brews(:morning_espresso),
      created_by: users(:one), updated_by: users(:one), title: "Public brew story",
      enabled: true, snapshot: {}
    )
    delete session_path
    assert_no_difference -> { ActivityEvent.count } do
      get public_brew_page_path(share.token)
    end
  end

  test "active filters with no matches render the filtered empty state" do
    sign_in_as(users(:one))

    get activity_path, params: { category: "coffee", start_date: "1900-01-01", end_date: "1900-01-01" }

    assert_response :success
    assert_select "[data-testid=activity-card]", count: 0
    assert_select "[data-testid=activity-empty]", text: I18n.t("activity.index.filtered_empty")
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
