require "test_helper"
require "zip"

class WorkspaceExportBuilderTest < ActiveSupport::TestCase
  RECIPIENT_EXPORT_KEYS = %i[
    recipient_kind recipient_user_id recipient_user_display_name recipient_user_email_address recipient_name cup_style
  ].freeze

  test "builds active workspace payload without other workspace data" do
    generated_at = Time.zone.parse("2026-05-26 10:15:00")
    bean_photo = attach_photo(beans(:open_household))
    tool_photo = attach_photo(preparation_tools(:wdt))
    finished_at = Time.zone.parse("2026-05-24 18:30:00")
    bean = beans(:open_household)
    bean.update!(
      remaining_grams: 14,
      finished_at:,
      continent: "South America",
      country_of_manufacturer: "Germany",
      manufacturer: "Calendar Coffee",
      purchase_url: "https://shop.example/house-blend",
      coffee_origin_url: "https://origin.example/house-blend"
    )

    payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at:).call

    assert_equal "roastnode.workspace_export", payload[:format]
    assert_equal 1, payload[:version]
    assert_equal generated_at.iso8601, payload[:generated_at]
    assert_equal workspaces(:household).id, payload[:workspace][:id]

    bean_ids = payload[:beans].pluck(:id)
    assert_includes bean_ids, beans(:open_household).id
    assert_not_includes bean_ids, beans(:other_workspace_open).id

    brew_ids = payload[:brews].pluck(:id)
    assert_includes brew_ids, brews(:morning_espresso).id
    assert_not_includes brew_ids, brews(:other_workspace_brew).id

    equipment_ids = payload[:equipment].pluck(:id)
    assert_includes equipment_ids, equipment(:household_grinder).id
    assert_not_includes equipment_ids, equipment(:other_workspace_grinder).id

    bean_payload = payload[:beans].find { |bean| bean[:id] == beans(:open_household).id }
    assert_equal "finished", bean_payload[:status]
    assert_equal "South America", bean_payload.fetch(:continent)
    assert_equal "Germany", bean_payload.fetch(:country_of_manufacturer)
    assert_equal "Calendar Coffee", bean_payload.fetch(:manufacturer)
    assert_equal "https://shop.example/house-blend", bean_payload.fetch(:purchase_url)
    assert_equal "https://origin.example/house-blend", bean_payload.fetch(:coffee_origin_url)
    assert_equal finished_at.iso8601, bean_payload[:finished_at]
    assert_equal bean_photo.id, bean_payload[:photos].first[:attachment_id]
    assert_equal "photo.jpg", bean_payload[:photos].first[:filename]
    assert_not bean_payload[:photos].first.key?(:url)

    tool_payload = payload[:preparation_tools].find { |tool| tool[:id] == preparation_tools(:wdt).id }
    assert_equal preparation_tools(:wdt).position, tool_payload[:position]
    assert_equal tool_photo.id, tool_payload[:photos].first[:attachment_id]
  end

  test "includes relationships needed to reconstruct workspace data" do
    duplicated = beans(:open_household).duplicate_for_new_bag!
    brews(:morning_espresso).update!(
      recipient_kind: "guest",
      recipient_name: "Anna",
      cup_style: "Latte",
      low_flow_start_seconds: 9,
      flow_control_used: true
    )
    payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at: Time.current).call

    membership = payload[:memberships].find { |row| row[:user_id] == users(:one).id }
    assert_equal users(:one).email_address, membership[:email_address]
    assert_equal "owner", membership[:role]

    brew = payload[:brews].find { |row| row[:id] == brews(:morning_espresso).id }
    assert_equal beans(:open_household).id, brew[:bean_id]
    assert_equal equipment(:household_grinder).id, brew[:grinder_id]
    assert_equal users(:one).id, brew[:user_id]
    assert_equal(
      {
        recipient_kind: "guest",
        recipient_user_id: nil,
        recipient_user_display_name: nil,
        recipient_user_email_address: nil,
        recipient_name: "Anna",
        cup_style: "Latte"
      },
      brew.slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert_not brew.key?(:served_for_guest)
    assert_not brew.key?(:guest_name)
    assert_equal 9, brew[:low_flow_start_seconds]
    assert_equal true, brew[:flow_control_used]

    machine = payload[:equipment].find { |row| row[:id] == equipment(:household_machine).id }
    assert_equal true, machine[:preinfusion_enabled]
    assert_equal true, machine[:low_flow_start_enabled]
    assert_equal true, machine[:flow_control_enabled]

    tool_snapshot = payload[:brew_preparation_tools].find { |row| row[:brew_id] == brews(:morning_espresso).id }
    assert_equal "WDT", tool_snapshot[:tool_name]

    event_link = payload[:equipment_event_items].find { |row| row[:equipment_event_id] == equipment_events(:grinder_cleaning).id }
    assert_equal equipment(:household_grinder).id, event_link[:equipment_id]

    duplicate_payload = payload[:beans].find { |row| row[:id] == duplicated.id }
    assert_equal beans(:open_household).id, duplicate_payload[:duplicated_from_bean_id]
  end

  test "exports private cupping feedback on brew JSON without exporting request capabilities" do
    workspace = workspaces(:household)
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Private Guest")
    request = CuppingRequests::Synchronize.call(brew)
    request.update!(feedback_comment: "Private cupping feedback")

    payload = WorkspaceExportBuilder.new(workspace, generated_at: Time.current).call
    exported_brew = payload.fetch(:brews).find { |row| row.fetch(:id) == brew.id }
    payload_json = JSON.generate(payload)

    assert_equal "Private cupping feedback", exported_brew.fetch(:cupping_feedback_comment)
    assert_not payload.key?(:cupping_requests)
    assert_not_includes payload_json, request.token
    assert_not_includes payload_json, request.token_digest

    csv = WorkspaceCsvExportBuilder.new(workspace).brews_csv
    assert_not_includes csv, "cupping_feedback_comment"
    assert_not_includes csv, "Private cupping feedback"
    assert_not_includes csv, request.token

    archive = WorkspaceMediaArchiveBuilder.new(workspace, generated_at: Time.current).call
    Zip::File.open_buffer(archive) do |zip|
      archive_json = zip.read("data/workspace-export.json")

      assert_includes archive_json, "Private cupping feedback"
      assert_not_includes archive_json, request.token
      assert_not_includes archive_json, request.token_digest
      assert_not_includes JSON.parse(archive_json).keys, "cupping_requests"
    end
  end

  test "exports exact recipient and cup fields for every serving kind including a former member" do
    workspace = workspaces(:household)
    logger = users(:one)
    current_recipient = users(:two)
    current_recipient.update!(display_name: nil)
    former_recipient = User.create!(
      email_address: "former-recipient@example.com",
      password: "password",
      display_name: "Former Recipient"
    )
    former_membership = workspace.memberships.create!(user: former_recipient, role: "member")
    brews(:morning_espresso).update!(recipient_kind: "self", cup_style: "Demitasse")
    current = create_recipient_brew(
      workspace:, logger:, recipient_kind: "household_member", recipient_user: current_recipient, cup_style: "Mug"
    )
    named_guest = create_recipient_brew(
      workspace:, logger:, recipient_kind: "guest", recipient_name: "Private Anna", cup_style: "Latte"
    )
    unnamed_guest = create_recipient_brew(
      workspace:, logger:, recipient_kind: "guest", recipient_name: nil, cup_style: nil
    )
    former = create_recipient_brew(
      workspace:, logger:, recipient_kind: "household_member", recipient_user: former_recipient, cup_style: "Cortado"
    )
    former_membership.destroy!

    payload = WorkspaceExportBuilder.new(workspace, generated_at: Time.current).call
    rows = payload.fetch(:brews).index_by { |row| row.fetch(:id) }

    assert_equal(
      {
        recipient_kind: "self", recipient_user_id: nil, recipient_user_display_name: nil,
        recipient_user_email_address: nil, recipient_name: nil, cup_style: "Demitasse"
      },
      rows.fetch(brews(:morning_espresso).id).slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert_equal(
      {
        recipient_kind: "household_member", recipient_user_id: current_recipient.id,
        recipient_user_display_name: User::UNKNOWN_DISPLAY_LABEL,
        recipient_user_email_address: current_recipient.email_address, recipient_name: nil, cup_style: "Mug"
      },
      rows.fetch(current.id).slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert_not_equal current_recipient.email_address, rows.fetch(current.id).fetch(:recipient_user_display_name)
    assert_equal(
      {
        recipient_kind: "guest", recipient_user_id: nil, recipient_user_display_name: nil,
        recipient_user_email_address: nil, recipient_name: "Private Anna", cup_style: "Latte"
      },
      rows.fetch(named_guest.id).slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert_equal(
      {
        recipient_kind: "guest", recipient_user_id: nil, recipient_user_display_name: nil,
        recipient_user_email_address: nil, recipient_name: nil, cup_style: nil
      },
      rows.fetch(unnamed_guest.id).slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert_equal(
      {
        recipient_kind: "household_member", recipient_user_id: former_recipient.id,
        recipient_user_display_name: "Former Recipient",
        recipient_user_email_address: former_recipient.email_address, recipient_name: nil, cup_style: "Cortado"
      },
      rows.fetch(former.id).slice(*RECIPIENT_EXPORT_KEYS)
    )
    assert rows.values.all? { |row| RECIPIENT_EXPORT_KEYS.all? { |key| row.key?(key) } }
    assert rows.values.none? { |row| row.key?(:served_for_guest) || row.key?(:guest_name) }
    assert_not_includes rows.keys, brews(:other_workspace_brew).id
  end

  test "recipient user selects stay bounded as brew count grows" do
    workspace = workspaces(:household)
    brews(:morning_espresso).update!(recipient_kind: "household_member", recipient_user: users(:two))
    one_brew_queries = capture_user_selects do
      WorkspaceExportBuilder.new(Workspace.find(workspace.id), generated_at: Time.current).call
    end

    5.times do
      create_recipient_brew(
        workspace:, logger: users(:one), recipient_kind: "household_member", recipient_user: users(:two)
      )
    end
    many_brew_queries = capture_user_selects do
      WorkspaceExportBuilder.new(Workspace.find(workspace.id), generated_at: Time.current).call
    end

    assert_equal one_brew_queries, many_brew_queries
  end

  test "exports quick drip fields and bean grind state" do
    beans(:second_open_household).update!(grind_state: "pre_ground")
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )

    payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at: Time.current).call

    bean_payload = payload[:beans].find { |row| row[:id] == beans(:second_open_household).id }
    assert_equal "pre_ground", bean_payload[:grind_state]

    brew_payload = payload[:brews].find { |row| row[:id] == brew.id }
    assert_equal equipment(:household_brewer).id, brew_payload[:brewer_id]
    assert_equal "6.0", brew_payload[:machine_cups]
    assert_equal "6.0", brew_payload[:coffee_spoons]
    assert_equal "5.0", brew_payload[:grams_per_coffee_spoon]
    assert_equal "estimated_spoons", brew_payload[:coffee_amount_source]
  end

  test "includes import batches and per-record import metadata" do
    import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "completed",
      summary: { "beans" => { "created" => 1 } }
    )
    beans(:open_household).update!(
      data_import: import,
      import_source: "beanconqueror",
      import_source_id: "bean-source-id",
      raw_import_data: { "name" => "Source Bean" }
    )

    payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at: Time.current).call

    assert_equal import.id, payload[:data_imports].first[:id]
    bean_payload = payload[:beans].find { |bean| bean[:id] == beans(:open_household).id }
    assert_equal import.id, bean_payload[:data_import_id]
    assert_equal "beanconqueror", bean_payload[:import_source]
    assert_equal "bean-source-id", bean_payload[:import_source_id]
    assert_equal({ "name" => "Source Bean" }, bean_payload[:raw_import_data])
  end

  test "workspace export contains only that workspace ledger and preserves safe snapshots" do
    payload = WorkspaceExportBuilder.new(workspaces(:household)).call

    ids = payload.fetch(:activity_events).map { |row| row.fetch(:id) }
    assert_includes ids, activity_events(:morning_brew_created).id
    assert_not_includes ids, activity_events(:other_workspace_brew).id
    assert payload.fetch(:activity_events).all? { |row| row.fetch(:workspace_id) == workspaces(:household).id }
    assert_no_match(/password|digest|token|signed_id|attachment|filename|https?:\/\//i, payload.fetch(:activity_events).to_json)
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

    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end
end
