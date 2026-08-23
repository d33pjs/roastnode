require "test_helper"

class WorkspaceStatisticsPeopleTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:household)
    users(:one).update!(display_name: "Jens")
    users(:two).update!(display_name: "Petra")
  end

  test "logger users include current members and historical workspace loggers once" do
    historical = User.create!(
      email_address: "historical-logger@example.com",
      password: "password",
      display_name: "Former logger"
    )
    membership = @workspace.memberships.create!(user: historical, role: "member")
    brews(:morning_espresso).update!(user: historical)
    membership.destroy!

    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_equal(
      [ "Former logger", "Jens", "Petra" ],
      people.logger_users.map(&:display_label)
    )
  end

  test "recipient users include current members and historical self or member recipients" do
    historical = User.create!(
      email_address: "historical-recipient@example.com",
      password: "password",
      display_name: "Former recipient"
    )
    membership = @workspace.memberships.create!(user: historical, role: "member")
    brews(:morning_espresso).update!(
      recipient_kind: "household_member",
      recipient_user: historical
    )
    membership.destroy!

    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_equal(
      [ "Former recipient", "Jens", "Petra" ],
      people.recipient_users.map(&:display_label)
    )
  end

  test "guest names never become recipient options" do
    brews(:morning_espresso).update!(
      recipient_kind: "guest",
      recipient_name: "Secret Guest"
    )

    labels = WorkspaceStatisticsPeople.new(workspace: @workspace)
      .recipient_users
      .map(&:display_label)

    refute_includes labels, "Secret Guest"
  end

  test "resolves blank built in and workspace user values" do
    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_nil people.resolve_logger_id(nil)
    assert_nil people.resolve_recipient_filter("")
    assert_equal users(:one).id, people.resolve_logger_id(users(:one).id.to_s)
    assert_equal "self", people.resolve_recipient_filter("self")
    assert_equal "guests", people.resolve_recipient_filter("guests")
    assert_equal(
      "user:#{users(:two).id}",
      people.resolve_recipient_filter("user:#{users(:two).id}")
    )
  end

  test "rejects malformed unknown and foreign logger ids" do
    people = WorkspaceStatisticsPeople.new(workspace: @workspace)
    foreign_id = users(:two).id
    brews(:morning_espresso).update!(user: users(:one))
    memberships(:member).destroy!

    [
      "abc",
      "999999",
      foreign_id.to_s,
      [],
      {},
      [ users(:one).id.to_s ],
      { "id" => users(:one).id.to_s }
    ].each do |value|
      assert_raises(ActiveRecord::RecordNotFound) do
        people.resolve_logger_id(value)
      end
    end
  end

  test "rejects malformed unknown and foreign recipient values" do
    people = WorkspaceStatisticsPeople.new(workspace: @workspace)
    foreign_id = users(:two).id
    memberships(:member).destroy!

    [
      "guest",
      "user:abc",
      "user:999999",
      "user:#{foreign_id}",
      [],
      {},
      [ "self" ],
      { "kind" => "self" }
    ].each do |value|
      assert_raises(ActiveRecord::RecordNotFound) do
        people.resolve_recipient_filter(value)
      end
    end
  end
end
