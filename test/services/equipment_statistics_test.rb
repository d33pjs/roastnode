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

    statistics = EquipmentStatistics.new(equipment: grinder, end_date: Date.new(2026, 5, 26)).call

    assert_equal 3, statistics[:totals][:brew_count]
    assert_equal 57.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 3.7.to_d, statistics[:averages][:rating]
    assert_equal 3, statistics[:rates][:channeling_brew_count]
    assert_equal 33, statistics[:rates][:channeling_percent]
    assert_equal service_event, statistics[:service][:last_event]
    assert_equal 1, statistics[:service][:brews_since_service]
    assert_equal 19.to_d, statistics[:service][:grams_since_service]
    assert_equal({ "burr_change" => 1, "grinder_cleaning" => 1, "grinder_deep_cleaning" => 1 }, statistics[:distributions][:event_types])

    assert_equal 1, statistics[:series][:brews_by_day].detect { |point| point[:date] == Date.new(2026, 5, 26) }[:count]
    assert_equal [ 19.to_d, 18.to_d, 20.to_d ], statistics[:recent_brews].map(&:bean_weight_grams)
    assert_equal [ service_event, equipment_events(:grinder_cleaning) ], statistics[:recent_events].first(2)
  end

  test "filters brew-derived equipment analytics by date range while keeping service counters current" do
    grinder = equipment(:household_grinder)
    bean = beans(:open_household)
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 5, 19, 8, 0, 0))
    brews(:morning_espresso).update!(
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      bean_weight_grams: 18,
      rating: 4,
      channeling: false
    )

    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 20, 8, 0, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 44,
      rating: 2,
      channeling: true
    )

    statistics = EquipmentStatistics.new(
      equipment: grinder,
      start_date: Date.new(2026, 5, 26),
      end_date: Date.new(2026, 5, 26)
    ).call

    assert_equal 1, statistics[:totals][:brew_count]
    assert_equal 18.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 4, statistics[:averages][:rating]
    assert_equal 1, statistics[:rates][:channeling_brew_count]
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal 2, statistics[:service][:brews_since_service]
    assert_equal 38.to_d, statistics[:service][:grams_since_service]
    assert_equal [ Date.new(2026, 5, 26) ], statistics[:series][:brews_by_day].map { |point| point[:date] }
    assert_equal [ 18.to_d ], statistics[:recent_brews].map(&:bean_weight_grams)
    assert_equal({ "grinder_cleaning" => 1 }, statistics[:distributions][:event_types])
  end

  test "builds brewer analytics from brewer brews" do
    brewer = equipment(:household_brewer)
    bean = beans(:open_household)
    machine_brew = bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 24, 8, 0, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 18,
      dose_grams: 18,
      beverage_grams: 40
    )
    brewer_brew = bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      brewer:,
      method: "quick_drip",
      occurred_at: Time.zone.local(2026, 5, 25, 8, 0, 0),
      machine_cups: 6,
      bean_weight_grams: 32,
      ground_weight_grams: 32,
      rating: 5
    )

    statistics = EquipmentStatistics.new(equipment: brewer).call

    assert_equal 1, statistics[:totals][:brew_count]
    assert_equal 32.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 5, statistics[:averages][:rating]
    assert_equal 0, statistics[:rates][:channeling_brew_count]
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal [ brewer_brew ], statistics[:recent_brews]
    assert_not_includes statistics[:recent_brews], machine_brew
  end

  test "uses brewer service events for brewer service counters" do
    brewer = equipment(:household_brewer)
    bean = beans(:open_household)
    user = users(:one)

    old_brew = bean.brews.create!(
      workspace: bean.workspace,
      user:,
      brewer:,
      method: "quick_drip",
      occurred_at: Time.zone.local(2026, 5, 24, 8, 0, 0),
      machine_cups: 6,
      coffee_spoons: 6,
      rating: 3,
      channeling: true
    )
    service_event = EquipmentEvent.new(
      workspace: brewer.workspace,
      user:,
      event_types: %w[brewer_cleaning filter_change],
      occurred_at: Time.zone.local(2026, 5, 25, 8, 0, 0)
    )
    service_event.equipment << brewer
    service_event.save!
    fresh_brew = bean.brews.create!(
      workspace: bean.workspace,
      user:,
      brewer:,
      method: "quick_drip",
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      machine_cups: 4,
      coffee_spoons: 4,
      rating: 5
    )

    statistics = EquipmentStatistics.new(equipment: brewer).call

    assert_equal 2, statistics[:totals][:brew_count]
    assert_equal 50.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 0, statistics[:rates][:channeling_brew_count]
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal service_event, statistics[:service][:last_event]
    assert_equal 1, statistics[:service][:brews_since_service]
    assert_equal 20.to_d, statistics[:service][:grams_since_service]
    assert_equal({ "brewer_cleaning" => 1, "filter_change" => 1 }, statistics[:distributions][:event_types])
    assert_equal [ fresh_brew, old_brew ], statistics[:recent_brews].first(2)
  end

  test "does not reset brewer service counters for non brewer service events" do
    brewer = equipment(:household_brewer)
    bean = beans(:open_household)
    user = users(:one)

    bean.brews.create!(
      workspace: bean.workspace,
      user:,
      brewer:,
      method: "quick_drip",
      occurred_at: Time.zone.local(2026, 5, 24, 8, 0, 0),
      machine_cups: 6,
      coffee_spoons: 6
    )
    non_brewer_event = EquipmentEvent.new(
      workspace: brewer.workspace,
      user:,
      event_types: %w[machine_backflush],
      occurred_at: Time.zone.local(2026, 5, 25, 8, 0, 0)
    )
    non_brewer_event.equipment << brewer
    non_brewer_event.save!
    bean.brews.create!(
      workspace: bean.workspace,
      user:,
      brewer:,
      method: "quick_drip",
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      machine_cups: 4,
      coffee_spoons: 4
    )

    statistics = EquipmentStatistics.new(equipment: brewer).call

    assert_nil statistics[:service][:last_event]
    assert_equal 2, statistics[:service][:brews_since_service]
    assert_equal 50.to_d, statistics[:service][:grams_since_service]
    assert_equal({ "machine_backflush" => 1 }, statistics[:distributions][:event_types])
  end
end
