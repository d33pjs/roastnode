require "test_helper"

class StatisticsPersonasTest < ActionView::TestCase
  include StatisticsHelper
  include ApplicationHelper

  test "renders accessible pairings and distinct bean histories for identical display labels" do
    render partial: "statistics/personas", locals: { personas: persona_payload }

    assert_select "[data-testid='statistics-persona-makers'] li", count: 1
    assert_select "[data-testid='statistics-persona-recipients'] li", count: 2
    assert_select "details[data-statistics-chart-target='fallback'][open]"
    assert_select "[data-testid='statistics-persona-pairings'] dd", text: "2"
    assert_select "[data-testid='statistics-persona-pairings'] dd", text: "1"
    assert_select "[data-testid='statistics-persona-beans']", count: 2 do |recipients|
      assert_select recipients.first, "[data-testid='statistics-persona-favorites']", text: /Colombia/
      assert_select recipients.first, "[data-testid='statistics-persona-favorites']", text: /1 rated out of 2 coffees/
      assert_select recipients.last, "[data-testid='statistics-persona-no-ratings']"
      assert_select recipients.last, "[data-testid='statistics-persona-favorites']", count: 0
    end
  end

  test "escapes guest and bean labels in HTML and chart data attributes" do
    personas = persona_payload
    unsafe_label = '</script><img src=x onerror="alert(1)">'
    personas[:servings][:labels][0] = unsafe_label
    personas[:servings][:datasets][0][:label] = unsafe_label
    personas[:recipient_beans][0][:beans][0][:label] = unsafe_label

    render partial: "statistics/personas", locals: { personas: }

    assert_select "img", count: 0
    assert_select "script", count: 0
    chart = css_select("[data-controller='statistics-chart']").first
    chart_data = JSON.parse(chart["data-statistics-chart-series-value"])
    assert_equal unsafe_label, chart_data["labels"].first
    assert_equal unsafe_label, chart_data["datasets"].first["label"]
  end

  test "empty filters explain missing data without winners charts or percentages" do
    render partial: "statistics/personas", locals: {
      personas: { makers: [], recipients: [], servings: { labels: [], datasets: [] }, recipient_beans: [], favorites: [], totals: {} }
    }

    assert_select "[data-testid='statistics-personas-empty']"
    assert_select "[data-testid='statistics-personas-guest-help']"
    assert_select "[data-controller='statistics-chart']", count: 0
    assert_select "[data-testid='statistics-persona-makers']", count: 0
    assert_select "dd", count: 0
  end

  private

  def persona_payload
    colombia = { label: "Colombia", count: 2, rated_count: 1, average_rating: 4.5 }
    ethiopia = { label: "Ethiopia", count: 1, rated_count: 0, average_rating: nil }
    {
      makers: [ { label: "Alex", count: 3, self_count: 2, others_count: 1 } ],
      recipients: [
        { label: "Alex", count: 2, bean_count: 1, rated_count: 1, average_rating: 4.5 },
        { label: "Alex", count: 1, bean_count: 1, rated_count: 0, average_rating: nil }
      ],
      servings: { labels: [ "Alex" ], datasets: [ { label: "Alex", data: [ 2 ] }, { label: "Alex", data: [ 1 ] } ] },
      recipient_beans: [ { label: "Alex", count: 2, beans: [ colombia ] }, { label: "Alex", count: 1, beans: [ ethiopia ] } ],
      favorites: [ { label: "Alex", beans: [ colombia ] }, { label: "Alex", beans: [] } ],
      totals: { self_served: 2, served_to_others: 1, recipient_count: 2, rated_count: 1 }
    }
  end
end
