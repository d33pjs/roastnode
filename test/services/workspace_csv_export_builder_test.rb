require "test_helper"
require "csv"

class WorkspaceCsvExportBuilderTest < ActiveSupport::TestCase
  RECIPIENT_COLUMNS = %w[
    recipient_kind recipient_user_id recipient_user_display_name recipient_user_email_address recipient_name cup_style
  ].freeze

  test "exports beans as workspace-scoped csv rows" do
    finished_at = Time.zone.parse("2026-05-24 18:30:00")
    beans(:open_household).update!(
      remaining_grams: 14,
      finished_at:,
      purchase_url: "https://shop.example/house-blend",
      coffee_origin_url: "https://origin.example/house-blend"
    )

    csv = WorkspaceCsvExportBuilder.new(workspaces(:household)).beans_csv
    rows = CSV.parse(csv, headers: true)

    assert_includes rows.headers, "id"
    assert_includes rows.headers, "name"
    assert_includes rows.headers, "remaining_grams"
    assert_includes rows.headers, "finished_at"
    assert_includes rows.headers, "purchase_price"
    assert_includes rows.headers, "grind_state"
    assert_includes rows.headers, "continent"
    assert_includes rows.headers, "country_of_manufacturer"
    assert_includes rows.headers, "manufacturer"
    purchase_url_index = rows.headers.index("purchase_url")
    assert_equal %w[purchase_url coffee_origin_url purchased_on purchase_price], rows.headers.slice(purchase_url_index, 4)

    bean_ids = rows.map { |row| row.fetch("id").to_i }
    assert_includes bean_ids, beans(:open_household).id
    assert_not_includes bean_ids, beans(:other_workspace_open).id

    exported = rows.find { |row| row.fetch("id").to_i == beans(:open_household).id }
    assert_equal beans(:open_household).name, exported.fetch("name")
    assert_equal beans(:open_household).remaining_grams.to_s("F"), exported.fetch("remaining_grams")
    assert_equal "finished", exported.fetch("status")
    assert_equal finished_at.iso8601, exported.fetch("finished_at")
    assert_equal "https://shop.example/house-blend", exported.fetch("purchase_url")
    assert_equal "https://origin.example/house-blend", exported.fetch("coffee_origin_url")

    archived = rows.find { |row| row.fetch("id").to_i == beans(:archived_household).id }
    assert_equal "archived", archived.fetch("status")

    pre_ground = rows.find { |row| row.fetch("id").to_i == beans(:second_open_household).id }
    assert_equal "pre_ground", pre_ground.fetch("grind_state")
  end

  test "exports brews as workspace-scoped csv rows with tool snapshots" do
    brews(:morning_espresso).update!(
      recipient_kind: "guest",
      recipient_name: "Anna",
      cup_style: "Latte",
      low_flow_start_seconds: 9,
      flow_control_used: true
    )

    csv = WorkspaceCsvExportBuilder.new(workspaces(:household)).brews_csv
    rows = CSV.parse(csv, headers: true)

    assert_includes rows.headers, "id"
    assert_includes rows.headers, "bean_name"
    assert_includes rows.headers, "preparation_tools"
    assert_includes rows.headers, "brew_ratio"
    serving_start = rows.headers.index("recipient_kind")
    assert_equal RECIPIENT_COLUMNS, rows.headers.slice(serving_start, RECIPIENT_COLUMNS.size)
    assert_not_includes rows.headers, "served_for_guest"
    assert_not_includes rows.headers, "guest_name"
    assert_includes rows.headers, "low_flow_start_seconds"
    assert_includes rows.headers, "flow_control_used"

    brew_ids = rows.map { |row| row.fetch("id").to_i }
    assert_includes brew_ids, brews(:morning_espresso).id
    assert_not_includes brew_ids, brews(:other_workspace_brew).id

    exported = rows.find { |row| row.fetch("id").to_i == brews(:morning_espresso).id }
    assert_equal brews(:morning_espresso).bean.name, exported.fetch("bean_name")
    assert_equal "WDT", exported.fetch("preparation_tools")
    assert_equal "1:2.22", exported.fetch("brew_ratio")
    assert_equal [ "guest", nil, nil, nil, "Anna", "Latte" ], RECIPIENT_COLUMNS.map { |column| exported[column] }
    assert_equal "9", exported.fetch("low_flow_start_seconds")
    assert_equal "true", exported.fetch("flow_control_used")
  end

  test "exports exact recipient csv cells for self current guest unnamed and former member" do
    workspace = workspaces(:household)
    logger = users(:one)
    current_recipient = users(:two)
    current_recipient.update!(display_name: nil)
    former_recipient = User.create!(
      email_address: "former-csv-recipient@example.com",
      password: "password",
      display_name: "Former CSV Recipient"
    )
    former_membership = workspace.memberships.create!(user: former_recipient, role: "member")
    brews(:morning_espresso).update!(recipient_kind: "self", cup_style: "Demitasse")
    current = create_recipient_brew(
      workspace:, logger:, recipient_kind: "household_member", recipient_user: current_recipient, cup_style: "Mug"
    )
    named_guest = create_recipient_brew(
      workspace:, logger:, recipient_kind: "guest", recipient_name: "Private Anna", cup_style: "Latte"
    )
    unnamed_guest = create_recipient_brew(workspace:, logger:, recipient_kind: "guest")
    former = create_recipient_brew(
      workspace:, logger:, recipient_kind: "household_member", recipient_user: former_recipient, cup_style: "Cortado"
    )
    former_membership.destroy!

    rows = CSV.parse(WorkspaceCsvExportBuilder.new(workspace).brews_csv, headers: true)
      .index_by { |row| row.fetch("id").to_i }

    assert_equal [ "self", nil, nil, nil, nil, "Demitasse" ], recipient_cells(rows.fetch(brews(:morning_espresso).id))
    assert_equal(
      [
        "household_member", current_recipient.id.to_s, User::UNKNOWN_DISPLAY_LABEL,
        current_recipient.email_address, nil, "Mug"
      ],
      recipient_cells(rows.fetch(current.id))
    )
    assert_not_equal current_recipient.email_address, rows.fetch(current.id).fetch("recipient_user_display_name")
    assert_equal [ "guest", nil, nil, nil, "Private Anna", "Latte" ], recipient_cells(rows.fetch(named_guest.id))
    assert_equal [ "guest", nil, nil, nil, nil, nil ], recipient_cells(rows.fetch(unnamed_guest.id))
    assert_equal(
      [
        "household_member", former_recipient.id.to_s, "Former CSV Recipient",
        former_recipient.email_address, nil, "Cortado"
      ],
      recipient_cells(rows.fetch(former.id))
    )
    assert_not_includes rows.keys, brews(:other_workspace_brew).id
  end

  test "recipient user selects stay bounded in uncached csv generation" do
    workspace = workspaces(:household)
    brews(:morning_espresso).update!(recipient_kind: "household_member", recipient_user: users(:two))
    one_brew_queries = capture_user_selects do
      WorkspaceCsvExportBuilder.new(Workspace.find(workspace.id)).brews_csv
    end

    5.times do
      create_recipient_brew(
        workspace:, logger: users(:one), recipient_kind: "household_member", recipient_user: users(:two)
      )
    end
    many_brew_queries = capture_user_selects do
      WorkspaceCsvExportBuilder.new(Workspace.find(workspace.id)).brews_csv
    end

    assert_equal one_brew_queries, many_brew_queries
  end

  test "exports quick drip csv columns" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )

    rows = CSV.parse(WorkspaceCsvExportBuilder.new(workspaces(:household)).brews_csv, headers: true)
    exported = rows.find { |row| row.fetch("id").to_i == brew.id }

    assert_equal "quick_drip", exported.fetch("method")
    assert_equal equipment(:household_brewer).id.to_s, exported.fetch("brewer_id")
    assert_equal "Moccamaster", exported.fetch("brewer_name")
    assert_equal "6.0", exported.fetch("machine_cups")
    assert_equal "6.0", exported.fetch("coffee_spoons")
    assert_equal "5.0", exported.fetch("grams_per_coffee_spoon")
    assert_equal "estimated_spoons", exported.fetch("coffee_amount_source")
  end


  private
    def create_recipient_brew(workspace:, logger:, recipient_kind:, recipient_user: nil, recipient_name: nil, cup_style: nil)
      workspace.brews.create!(
        user: logger,
        bean: beans(:open_household),
        method: "espresso",
        bean_weight_grams: 1,
        recipient_kind:,
        recipient_user:,
        recipient_name:,
        cup_style:
      )
    end

    def recipient_cells(row)
      RECIPIENT_COLUMNS.map { |column| row[column] }
    end

    def capture_user_selects
      queries = []
      callback = lambda do |_name, _started, _finished, _unique_id, payload|
        queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].match?(/FROM "users"/i)
      end
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      end
      queries.size
    end
end
