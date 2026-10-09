require "test_helper"

class WorkspaceWasteStatisticsTest < ActiveSupport::TestCase
  test "ranks finished leftovers and measured waste and channeling within workspace" do
    source = beans(:open_household)
    source.update!(remaining_grams: 14)
    source.finish!
    beans(:other_workspace_open).update!(finished_at: Time.current, remaining_grams: 180)
    brew = brews(:morning_espresso)
    brew.update!(ground_weight_grams: 20, dose_grams: 18, channeling: true)
    result = WorkspaceStatistics.new(workspace: workspaces(:household)).call.fetch(:waste)
    assert_equal [ source.id ], result[:leftovers].map { |row| row[:bean].id }
    assert_equal 14.to_d, result[:leftovers].first[:grams]
    assert_equal 2.to_d, result[:grounds].first[:grams]
    assert_equal 1, result[:grounds].first[:sample_count]
    assert_equal 1, result[:channeling].first[:count]
    assert_equal 100, result[:channeling].first[:percent]
  end

  test "brew waste respects date logger and recipient while leftovers remain current" do
    source = beans(:open_household)
    source.update!(remaining_grams: 14, finished_at: Time.current)
    brew = brews(:morning_espresso)
    brew.update!(ground_weight_grams: 20, dose_grams: 18, channeling: true)
    [ { logger_id: users(:two).id }, { recipient_filter: "guests" },
      { start_date: 20.days.ago.to_date, end_date: 15.days.ago.to_date } ].each do |filters|
      result = WorkspaceStatistics.new(workspace: workspaces(:household), **filters).call.fetch(:waste)
      assert_empty result[:grounds]
      assert_empty result[:channeling]
      assert_equal 14.to_d, result[:leftovers].first[:grams]
    end
  end

  test "unknown and negative grounds measurements are excluded and channeling nil is not a known result" do
    brew = brews(:morning_espresso)
    brew.update!(ground_weight_grams: 17, dose_grams: 18, channeling: nil)
    result = WorkspaceStatistics.new(workspace: workspaces(:household)).call.fetch(:waste)
    assert_empty result[:grounds]
    assert_empty result[:channeling]
    brew.update!(ground_weight_grams: nil, dose_grams: nil)
    assert_empty WorkspaceStatistics.new(workspace: workspaces(:household)).call.fetch(:waste)[:grounds]
  end

  test "transferred leftovers are not waste" do
    source = beans(:open_household)
    BeanLeftoverTransfer.new(source:, destination: "new", user: users(:one)).call
    assert_empty WorkspaceStatistics.new(workspace: source.workspace).call.fetch(:waste)[:leftovers]
  end
end
