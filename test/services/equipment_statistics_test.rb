require "test_helper"

class EquipmentStatisticsTest < ActiveSupport::TestCase
  test "builds grinder usage and maintenance analytics" do
    grinder = equipment(:household_grinder)
    user = users(:one)
    bean = beans(:open_household)

    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 5, 24, 8, 0, 0))
    brews(:morning_espresso).update!(
      occurred_at: Time.zone.local(2026, 5, 25, 8, 0, 0),
      bean_weight_grams: 18,
      beverage_grams: 40,
      rating: 4,
      channeling: false
    )

    bean.brews.create!(
      workspace: bean.workspace,
      user:,
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 23, 8, 0, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 44,
      rating: 2,
      channeling: true
    )

    service_event = EquipmentEvent.new(
      workspace: grinder.workspace,
      user:,
      event_type: "grinder_deep_cleaning",
      event_types: %w[grinder_deep_cleaning burr_change],
      occurred_at: Time.zone.local(2026, 5, 25, 12, 0, 0)
    )
    service_event.equipment << grinder
    service_event.save!

    bean.brews.create!(
      workspace: bean.workspace,
      user:,
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      bean_weight_grams: 19,
      ground_weight_grams: 19,
      dose_grams: 19,
      beverage_grams: 46,
      rating: 5,
      channeling: false
    )

    statistics = EquipmentStatistics.new(equipment: grinder).call

    assert_equal 3, statistics[:totals][:brew_count]
    assert_equal 57.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 3.7.to_d, statistics[:averages][:rating]
    assert_equal 33, statistics[:rates][:channeling_percent]
    assert_equal service_event, statistics[:service][:last_event]
    assert_equal 1, statistics[:service][:brews_since_service]
    assert_equal 19.to_d, statistics[:service][:grams_since_service]
    assert_equal({ "burr_change" => 1, "grinder_cleaning" => 1, "grinder_deep_cleaning" => 1 }, statistics[:distributions][:event_types])

    assert_equal 1, statistics[:series][:brews_by_day].detect { |point| point[:date] == Date.new(2026, 5, 26) }[:count]
    assert_equal [ 19.to_d, 18.to_d, 20.to_d ], statistics[:recent_brews].map(&:bean_weight_grams)
    assert_equal [ service_event, equipment_events(:grinder_cleaning) ], statistics[:recent_events].first(2)
  end
end
