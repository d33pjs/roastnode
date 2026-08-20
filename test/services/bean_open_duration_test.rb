require "test_helper"

class BeanOpenDurationTest < ActiveSupport::TestCase
  test "open bag runs through today" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10))

    assert_equal 16, BeanOpenDuration.new(
      bean:,
      latest_brew_at: Time.zone.local(2026, 5, 20, 9),
      today: Date.new(2026, 5, 26)
    ).call
  end

  test "finished bag stops at finished date" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 23, 9)
    )

    assert_equal 13, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "archived bag stops at archived date" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      archived_at: Time.zone.local(2026, 5, 21, 9)
    )

    assert_equal 11, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "used up bag stops at latest brew date" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10), remaining_grams: 0)

    assert_equal 12, BeanOpenDuration.new(
      bean:,
      latest_brew_at: Time.zone.local(2026, 5, 22, 9),
      today: Date.new(2026, 6, 1)
    ).call
  end

  test "used up bag without a brew falls back to today" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10), remaining_grams: 0)

    assert_equal 22, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "stock bag has no open duration" do
    assert_nil BeanOpenDuration.new(bean: build_bean(opened_on: nil), today: Date.new(2026, 6, 1)).call
  end

  test "terminal date before opening clamps to zero" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      archived_at: Time.zone.local(2026, 5, 8, 9)
    )

    assert_equal 0, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  private
    def build_bean(opened_on:, remaining_grams: 100, finished_at: nil, archived_at: nil)
      Bean.new(
        name: "Duration bean",
        bag_size_grams: 250,
        remaining_grams:,
        opened_on:,
        finished_at:,
        archived_at:
      )
    end
end
