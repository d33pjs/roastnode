require "test_helper"

class WorkspacePersonaStatisticsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:household)
    @maker = users(:one)
    @recipient = users(:two)
    @maker.update!(display_name: "Jens")
    @recipient.update!(display_name: "Petra")
    brews(:morning_espresso).update!(occurred_at: 2.years.ago)
  end

  test "counts makers, actual recipients, self service, and named guest pairings" do
    2.times { coffee }
    coffee(recipient_kind: "household_member", recipient_user: @recipient)
    coffee(recipient_kind: "guest", recipient_name: "Alex")
    coffee(user: @recipient, recipient_kind: "household_member", recipient_user: @maker)

    result = statistics

    assert_equal [ [ "Jens", 4, 2, 2 ], [ "Petra", 1, 0, 1 ] ], result[:makers].map { |row| row.values_at(:label, :count, :self_count, :others_count) }
    assert_equal [ [ "Jens", 3 ], [ guest_label("Alex"), 1 ], [ "Petra", 1 ] ], result[:recipients].map { |row| row.values_at(:label, :count) }
    assert_equal({ self_served: 2, served_to_others: 3, recipient_count: 3, rated_count: 0 }, result[:totals])
    assert_equal [ "Jens", "Petra" ], result[:servings][:labels]
    assert_equal [ 2, 1 ], result[:servings][:datasets].find { |row| row[:label] == "Jens" }[:data]
    assert_equal [ 1, 0 ], result[:servings][:datasets].find { |row| row[:label] == "Petra" }[:data]
    assert_equal 5, result[:servings][:datasets].sum { |row| row[:data].sum }
  end

  test "groups guest names case insensitively and keeps unnamed guests and users separate" do
    coffee(recipient_kind: "guest", recipient_name: " Alex ")
    coffee(recipient_kind: "guest", recipient_name: "alex")
    coffee(recipient_kind: "guest", recipient_name: "Jens")
    coffee(recipient_kind: "guest", recipient_name: nil)
    coffee(recipient_kind: "guest", recipient_name: " ")
    coffee

    rows = statistics[:recipients]
    assert_equal 4, rows.size
    assert_equal [ 2, 2, 1, 1 ], rows.map { |row| row[:count] }
    assert_equal 2, rows.find { |row| row[:label] == guest_label("Alex") }[:count]
    assert_equal 2, rows.find { |row| row[:label] == I18n.t("statistics.personas.unnamed_guests") }[:count]
    assert_equal 1, rows.find { |row| row[:label] == "Jens" }[:count]
    assert_equal 1, rows.find { |row| row[:label] == guest_label("Jens") }[:count]
  end

  test "calculates recipient bean counts and favorites from rated brews without counting missing ratings as zero" do
    coffee(rating: 5)
    coffee(rating: 3)
    coffee
    coffee(bean: beans(:second_open_household), rating: 5)
    coffee(user: @recipient, rating: 2)

    result = statistics
    jens = result[:recipients].find { |row| row[:label] == "Jens" }
    assert_equal 2, jens[:bean_count]
    assert_equal 3, jens[:rated_count]
    assert_in_delta 13.0 / 3, jens[:average_rating], 0.0001
    favorites = result[:favorites].find { |row| row[:label] == "Jens" }[:beans]
    assert_equal [ 5.0, 4.0 ], favorites.map { |row| row[:average_rating] }
    assert_equal [ 1, 2 ], favorites.map { |row| row[:rated_count] }
    assert_equal [ 1, 3 ], favorites.map { |row| row[:count] }
    assert_equal 2.0, result[:favorites].find { |row| row[:label] == "Petra" }[:beans].first[:average_rating]
    assert_equal 4, result[:totals][:rated_count]
  end

  test "guest name grouping folds German letter case" do
    coffee(recipient_kind: "guest", recipient_name: "Groß")
    coffee(recipient_kind: "guest", recipient_name: "GROSS")

    assert_equal [ 2 ], statistics[:recipients].map { |row| row[:count] }
  end

  test "favorites rank full averages before rounding their displayed scores" do
    coffee(rating: 5)
    18.times { coffee(rating: 4) }
    coffee(bean: beans(:second_open_household), rating: 5)
    20.times { coffee(bean: beans(:second_open_household), rating: 4) }

    favorites = statistics[:favorites].first[:beans]
    assert_operator favorites.first[:average_rating], :>, favorites.last[:average_rating]
    assert_equal [ 19, 21 ], favorites.map { |row| row[:rated_count] }
  end

  test "favorites include recipients with no ratings and keep identically named bean bags distinct" do
    other_bean = beans(:second_open_household)
    other_bean.update!(name: beans(:open_household).name, roaster_name: beans(:open_household).roaster_name)
    coffee(rating: 4)
    coffee(rating: 4)
    coffee(bean: other_bean, rating: 4)
    coffee(user: @recipient)

    result = statistics
    rows = result[:favorites].find { |row| row[:label] == "Jens" }[:beans]
    assert_equal 2, rows.size
    assert_equal [ 2, 1 ], rows.map { |row| row[:rated_count] }
    assert_empty result[:favorites].find { |row| row[:label] == "Petra" }[:beans]
    petra = result[:recipient_beans].find { |row| row[:label] == "Petra" }[:beans].first
    assert_equal 0, petra[:rated_count]
    assert_nil petra[:average_rating]
  end

  test "does not merge two users with identical display labels" do
    @recipient.update!(display_name: @maker.display_name)
    coffee
    coffee(user: @recipient)

    result = statistics
    assert_equal [ 1, 1 ], result[:makers].map { |row| row[:count] }
    assert_equal [ 1, 1 ], result[:recipients].map { |row| row[:count] }
    assert_equal 2, result[:servings][:datasets].size
    assert_equal [ [ 0, 1 ], [ 1, 0 ] ], result[:servings][:datasets].map { |row| row[:data] }.sort
  end

  test "retains historical recipient and maker labels without requiring current membership" do
    coffee(user: @recipient)
    coffee(recipient_kind: "household_member", recipient_user: @recipient)
    memberships(:member).delete

    result = statistics
    assert_includes result[:makers].map { |row| row[:label] }, "Petra"
    assert_equal 2, result[:recipients].find { |row| row[:label] == "Petra" }[:count]
  end

  test "counts Quick Drip preparations once rather than multiplying machine cups" do
    coffee(method: "quick_drip", brewer: equipment(:household_brewer), machine_cups: 8)

    assert_equal 1, statistics[:makers].first[:count]
    assert_equal 1, statistics[:recipients].first[:count]
  end

  test "honors combined date logger and recipient scope without including another workspace" do
    coffee(rating: 5)
    coffee(recipient_kind: "household_member", recipient_user: @recipient, rating: 4)
    coffee(user: @recipient, rating: 1)
    coffee(recipient_kind: "guest", recipient_name: "Private visitor", occurred_at: 30.days.ago)
    brews(:other_workspace_brew).update!(rating: 1)

    result = statistics(logger_id: @maker.id, recipient_filter: "user:#{@recipient.id}")
    assert_equal [ "Jens" ], result[:makers].map { |row| row[:label] }
    assert_equal [ "Petra" ], result[:recipients].map { |row| row[:label] }
    assert_equal 4.0, result[:recipients].first[:average_rating]
    assert_equal 1, result[:totals][:served_to_others]
    assert_equal 3, statistics[:makers].sum { |row| row[:count] }
  end

  test "self and guest scopes apply consistently to every persona aggregate" do
    coffee(rating: 5)
    coffee(recipient_kind: "guest", recipient_name: "Alex", rating: 2)
    coffee(recipient_kind: "household_member", recipient_user: @recipient, rating: 4)

    self_result = statistics(recipient_filter: "self")
    assert_equal 1, self_result[:totals][:self_served]
    assert_equal 0, self_result[:totals][:served_to_others]
    assert_equal 5.0, self_result[:favorites].first[:beans].first[:average_rating]
    guest_result = statistics(recipient_filter: "guests")
    assert_equal [ guest_label("Alex") ], guest_result[:recipients].map { |row| row[:label] }
    assert_equal 2.0, guest_result[:favorites].first[:beans].first[:average_rating]
  end

  test "empty scope has no invented people ratings or winners" do
    result = statistics
    %i[makers recipients recipient_beans favorites].each { |key| assert_empty result.fetch(key) }
    assert_equal({ labels: [], datasets: [] }, result[:servings])
    assert_equal({ self_served: 0, served_to_others: 0, recipient_count: 0, rated_count: 0 }, result[:totals])
  end

  test "aggregate payload exposes only labels and numeric statistics" do
    coffee(recipient_kind: "guest", recipient_name: "Alex", notes: "secret notes", public_note: "public description")
    json = statistics.to_json
    [ @maker.email_address, @recipient.email_address, "secret notes", "public description", "workspace_id", "user_id", "bean_id", "token", "attachment" ].each do |private_value|
      assert_not_includes json, private_value
    end
  end

  private
    def coffee(**attributes)
      @workspace.brews.create!({ user: @maker, bean: beans(:open_household), bean_weight_grams: 18, occurred_at: Time.current }.merge(attributes))
    end

    def statistics(**filters)
      WorkspaceStatistics.new(workspace: @workspace, **filters).call.fetch(:personas)
    end

    def guest_label(name)
      I18n.t("statistics.personas.named_guest", name:)
    end
end
