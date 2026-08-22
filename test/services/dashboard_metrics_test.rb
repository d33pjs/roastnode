require "test_helper"

class DashboardMetricsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:household)
    @other_workspace = workspaces(:other_household)
    @user = users(:one)
    @other_user = users(:two)
    @bean = beans(:open_household)
    @other_bean = beans(:other_workspace_open)
  end

  test "counts brews and external coffees with rough spend in the active workspace" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      move_existing_coffees_out_of_range
      @bean.update!(bag_size_grams: 250, remaining_grams: 1000, purchase_price_cents: 1000)
      brews(:morning_espresso).update!(
        occurred_at: Time.zone.local(2026, 6, 10, 8, 0, 0),
        bean_weight_grams: 20
      )
      external_today = create_external_coffee!(
        occurred_at: Time.zone.local(2026, 6, 10, 9, 0, 0),
        price_cents: 450
      )
      create_external_coffee!(
        occurred_at: Time.zone.local(2026, 6, 9, 9, 0, 0),
        price_cents: 300
      )
      create_external_coffee!(
        workspace: @other_workspace,
        user: @other_user,
        occurred_at: Time.zone.local(2026, 6, 10, 10, 0, 0),
        price_cents: 999
      )

      metrics = DashboardMetrics.new(workspace: @workspace, now: Time.current).call

      assert_equal 2, metrics[:counts][:coffees_today]
      assert_equal 3, metrics[:counts][:coffees_this_week]
      assert_equal 1, metrics[:counts][:brews_today]
      assert_equal 1, metrics[:counts][:brews_this_week]
      assert_equal 530, metrics[:spend][:today_cents]
      assert_equal 830, metrics[:spend][:week_cents]
      assert_equal external_today.occurred_at.to_i, metrics[:last_coffee_at].to_i
    end
  end

  test "last coffee timer ignores guest recipients but retains self and household recipients" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      move_existing_coffees_out_of_range
      own_brew = brews(:morning_espresso)
      own_brew.update!(
        occurred_at: Time.zone.local(2026, 6, 10, 8, 0, 0)
      )
      household_brew = @workspace.brews.create!(
        user: @user,
        method: "espresso",
        bean: @bean,
        bean_weight_grams: 18,
        occurred_at: Time.zone.local(2026, 6, 10, 9, 0, 0),
        recipient_kind: "household_member",
        recipient_user: users(:two)
      )
      @workspace.brews.create!(
        user: @user,
        method: "espresso",
        bean: @bean,
        bean_weight_grams: 18,
        occurred_at: Time.zone.local(2026, 6, 10, 9, 0, 0),
        recipient_kind: "guest",
        recipient_name: "Anna"
      )

      metrics = DashboardMetrics.new(workspace: @workspace, now: Time.current).call

      assert_equal household_brew.occurred_at.to_i, metrics[:last_coffee_at].to_i
    end
  end

  test "splits unopened stock inventory from open bean remaining inventory" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      move_existing_coffees_out_of_range
      @bean.update!(opened_on: Date.new(2026, 5, 10), remaining_grams: 150)
      beans(:second_open_household).update!(opened_on: Date.new(2026, 5, 12), remaining_grams: 220)
      @workspace.beans.create!(
        name: "Finished Today",
        roaster_name: "Done Roaster",
        bag_size_grams: 250,
        remaining_grams: 0,
        opened_on: Date.new(2026, 5, 1),
        finished_at: Time.zone.local(2026, 6, 10, 8, 0, 0)
      )
      @workspace.beans.create!(
        name: "Finished This Week",
        roaster_name: "Done Roaster",
        bag_size_grams: 250,
        remaining_grams: 0,
        opened_on: Date.new(2026, 5, 1),
        finished_at: Time.zone.local(2026, 6, 8, 8, 0, 0)
      )
      @workspace.beans.create!(
        name: "Finished Last Week",
        roaster_name: "Done Roaster",
        bag_size_grams: 250,
        remaining_grams: 0,
        opened_on: Date.new(2026, 5, 1),
        finished_at: Time.zone.local(2026, 6, 1, 8, 0, 0)
      )
      @workspace.beans.create!(
        name: "Unopened Reserve",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 500,
        remaining_grams: 500,
        opened_on: nil
      )
      @other_workspace.beans.create!(
        name: "Other Shelf",
        roaster_name: "Other Roaster",
        bag_size_grams: 750,
        remaining_grams: 750,
        opened_on: nil
      )
      @other_workspace.beans.create!(
        name: "Other Finished",
        roaster_name: "Other Roaster",
        bag_size_grams: 250,
        remaining_grams: 0,
        opened_on: Date.new(2026, 5, 1),
        finished_at: Time.zone.local(2026, 6, 10, 9, 0, 0)
      )

      metrics = DashboardMetrics.new(workspace: @workspace, now: Time.current).call

      assert_equal 2, metrics[:inventory][:open_bean_count]
      assert_equal 1, metrics[:inventory][:stock_bag_count]
      assert_equal 500.to_d, metrics[:inventory][:stock_grams]
      assert_equal 370.to_d, metrics[:inventory][:open_grams]
      assert_equal 1, metrics[:inventory][:closed_bags_today]
      assert_equal 2, metrics[:inventory][:closed_bags_this_week]
    end
  end

  test "compares today metrics to the same weekday over the last four completed weeks" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      move_existing_coffees_out_of_range
      create_external_coffees_on(Date.new(2026, 5, 13), 1)
      create_external_coffees_on(Date.new(2026, 5, 20), 2)
      create_external_coffees_on(Date.new(2026, 5, 27), 3)
      create_external_coffees_on(Date.new(2026, 6, 3), 4)
      create_external_coffees_on(Date.new(2026, 6, 10), 5)

      comparison = DashboardMetrics.new(workspace: @workspace, now: Time.current).call[:comparisons][:coffees_today]

      assert_equal "+100% over last 4 weeks", comparison[:label]
      assert_equal "up", comparison[:direction]
      assert_equal [ 1, 2, 3, 4, 5 ], comparison[:values]
      assert_equal 0.to_d, comparison[:scale_min]
      assert_equal 5.to_d, comparison[:scale_max]
    end
  end

  test "compares week metrics to the last four completed weeks and handles zero baselines" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      move_existing_coffees_out_of_range
      create_external_coffees_on(Date.new(2026, 6, 2), 2)
      create_external_coffees_on(Date.new(2026, 5, 26), 2)
      create_external_coffees_on(Date.new(2026, 5, 19), 2)
      create_external_coffees_on(Date.new(2026, 5, 12), 2)
      create_external_coffees_on(Date.new(2026, 6, 9), 1, price_cents: 200)

      metrics = DashboardMetrics.new(workspace: @workspace, now: Time.current).call

      assert_equal "-50% over last 4 weeks", metrics[:comparisons][:coffees_this_week][:label]
      assert_equal "down", metrics[:comparisons][:coffees_this_week][:direction]
      assert_equal 0.to_d, metrics[:comparisons][:coffees_this_week][:scale_min]
      assert_equal 2.to_d, metrics[:comparisons][:coffees_this_week][:scale_max]
      assert_equal "new over last 4 weeks", metrics[:comparisons][:spent_this_week][:label]
      assert_equal "new", metrics[:comparisons][:spent_this_week][:direction]
    end
  end

  private
    def move_existing_coffees_out_of_range
      @workspace.brews.update_all(occurred_at: Time.zone.local(2025, 1, 1, 12, 0, 0))
      @other_workspace.brews.update_all(occurred_at: Time.zone.local(2025, 1, 1, 12, 0, 0))
      ExternalCoffee.delete_all
    end

    def create_external_coffees_on(date, count, price_cents: nil)
      count.times do |index|
        create_external_coffee!(
          occurred_at: date.in_time_zone.change(hour: 8, min: index),
          price_cents:
        )
      end
    end

    def create_external_coffee!(workspace: @workspace, user: @user, occurred_at:, price_cents: nil)
      workspace.external_coffees.create!(
        user:,
        drink_type: "Flat White",
        occurred_at:,
        price_cents:,
        currency: workspace.default_currency
      )
    end
end
