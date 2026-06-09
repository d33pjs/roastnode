require "test_helper"

class ExternalCoffeeActivityFeedTest < ActiveSupport::TestCase
  test "workspace activity includes external coffees" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Black Coffee",
      occurred_at: Time.zone.local(2026, 6, 9, 12, 0, 0)
    )

    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_includes records, coffee
  end
end
