require "test_helper"

class WasteStatisticsControllerTest < ActionDispatch::IntegrationTest
  test "private statistics render all rankings and explain different filter scopes" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    source.update!(remaining_grams: 14, finished_at: Time.current)
    brews(:morning_espresso).update!(ground_weight_grams: 20, dose_grams: 18, channeling: true)
    get statistics_path
    assert_response :success
    %w[leftovers grounds channeling].each do |kind|
      assert_select "[data-testid=statistics-waste-#{kind}] a[href=?]", bean_path(source)
    end
    assert_select "[data-testid=statistics-waste-leftovers]", text: /All-time/
    assert_select "[data-testid=statistics-waste-grounds]", text: /Measured ground coffee/
    assert_select "body", text: /Translation missing/, count: 0
    assert_select "a[href=?]", bean_path(beans(:other_workspace_open)), count: 0
  end
end
