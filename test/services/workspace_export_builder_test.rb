require "test_helper"

class WorkspaceExportBuilderTest < ActiveSupport::TestCase
  test "builds active workspace payload without other workspace data" do
    generated_at = Time.zone.parse("2026-05-26 10:15:00")
    bean_photo = attach_photo(beans(:open_household))
    tool_photo = attach_photo(preparation_tools(:wdt))

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
    assert_equal "open", bean_payload[:status]
    assert_equal bean_photo.id, bean_payload[:photos].first[:attachment_id]
    assert_equal "photo.jpg", bean_payload[:photos].first[:filename]
    assert_not bean_payload[:photos].first.key?(:url)

    tool_payload = payload[:preparation_tools].find { |tool| tool[:id] == preparation_tools(:wdt).id }
    assert_equal preparation_tools(:wdt).position, tool_payload[:position]
    assert_equal tool_photo.id, tool_payload[:photos].first[:attachment_id]
  end

  test "includes relationships needed to reconstruct workspace data" do
    payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at: Time.current).call

    membership = payload[:memberships].find { |row| row[:user_id] == users(:one).id }
    assert_equal users(:one).email_address, membership[:email_address]
    assert_equal "owner", membership[:role]

    brew = payload[:brews].find { |row| row[:id] == brews(:morning_espresso).id }
    assert_equal beans(:open_household).id, brew[:bean_id]
    assert_equal equipment(:household_grinder).id, brew[:grinder_id]
    assert_equal users(:one).id, brew[:user_id]

    tool_snapshot = payload[:brew_preparation_tools].find { |row| row[:brew_id] == brews(:morning_espresso).id }
    assert_equal "WDT", tool_snapshot[:tool_name]

    event_link = payload[:equipment_event_items].find { |row| row[:equipment_event_id] == equipment_events(:grinder_cleaning).id }
    assert_equal equipment(:household_grinder).id, event_link[:equipment_id]
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

  private
    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end
end
