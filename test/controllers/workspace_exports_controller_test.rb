require "test_helper"
require "csv"
require "zip"

class WorkspaceExportsControllerTest < ActionDispatch::IntegrationTest
  test "owner downloads active workspace export as json attachment" do
    sign_in_as(users(:one))

    get workspace_export_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "jens-household-export.json", response.headers["Content-Disposition"]

    payload = JSON.parse(response.body)
    assert_equal "roastnode.workspace_export", payload.fetch("format")
    assert_equal workspaces(:household).id, payload.fetch("workspace").fetch("id")
    assert_includes payload.fetch("beans").map { |bean| bean.fetch("id") }, beans(:open_household).id
    assert_not_includes payload.fetch("beans").map { |bean| bean.fetch("id") }, beans(:other_workspace_open).id

    exported_bean = payload.fetch("beans").find { |bean| bean.fetch("id") == beans(:open_household).id }
    assert_equal beans(:open_household).roast_type, exported_bean.fetch("roast_type")
    assert_equal beans(:open_household).blend_type, exported_bean.fetch("blend_type")
    assert_equal beans(:open_household).decaffeinated, exported_bean.fetch("decaffeinated")
    assert_equal beans(:open_household).country, exported_bean.fetch("country")
    assert_equal beans(:open_household).blend_percentage, exported_bean.fetch("blend_percentage")
  end

  test "member cannot export workspace" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get workspace_export_path

    assert_redirected_to root_path
  end

  test "owner downloads beans csv export" do
    sign_in_as(users(:one))

    get workspace_export_beans_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "jens-household-beans.csv", response.headers["Content-Disposition"]

    rows = CSV.parse(response.body, headers: true)
    assert_includes rows.map { |row| row.fetch("id").to_i }, beans(:open_household).id
    assert_not_includes rows.map { |row| row.fetch("id").to_i }, beans(:other_workspace_open).id
  end

  test "owner downloads brews csv export" do
    sign_in_as(users(:one))

    get workspace_export_brews_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "jens-household-brews.csv", response.headers["Content-Disposition"]

    rows = CSV.parse(response.body, headers: true)
    assert_includes rows.map { |row| row.fetch("id").to_i }, brews(:morning_espresso).id
    assert_not_includes rows.map { |row| row.fetch("id").to_i }, brews(:other_workspace_brew).id
  end

  test "member cannot export workspace csv files" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get workspace_export_beans_path
    assert_redirected_to root_path

    get workspace_export_brews_path
    assert_redirected_to root_path
  end

  test "owner downloads media zip export" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get workspace_export_media_path

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "jens-household-media.zip", response.headers["Content-Disposition"]

    entries = read_zip_entries(response.body)
    assert_includes entries.keys, "manifest.json"
    manifest = JSON.parse(entries.fetch("manifest.json"))
    file = manifest.fetch("files").find { |row| row.fetch("attachment_id") == attachment.id }
    assert_equal "Bean", file.fetch("record_type")
    assert_includes entries.keys, file.fetch("path")
  end

  test "member cannot export media zip" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get workspace_export_media_path

    assert_redirected_to root_path
  end

  test "each successful workspace export emits exactly its allowlisted kind" do
    sign_in_as(users(:one))
    cases = [
      [ workspace_export_path, "json" ],
      [ workspace_export_beans_path, "beans_csv" ],
      [ workspace_export_brews_path, "brews_csv" ],
      [ workspace_export_external_coffees_path, "external_coffees_csv" ],
      [ workspace_export_media_path, "media_zip" ]
    ]

    cases.each do |path, export_kind|
      event = assert_activity_event(
        action: "workspace_export.generated", workspace: workspaces(:household),
        actor: users(:one), subject: workspaces(:household)
      ) do
        get path
      end
      assert_response :success
      assert_equal export_kind, event.metadata.fetch("export_kind")
    end
  end

  test "external coffees generation exception emits no export activity" do
    sign_in_as(users(:one))
    failing_export = Object.new
    failing_export.define_singleton_method(:external_coffees_csv) { raise "csv generation failed" }

    assert_no_difference -> { ActivityEvent.count } do
      with_stubbed_singleton_method(WorkspaceCsvExportBuilder, :new, ->(*) { failing_export }) do
        assert_raises(RuntimeError) { get workspace_export_external_coffees_path }
      end
    end
  end

  private
    def attach_photo(record)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end

    def read_zip_entries(archive)
      entries = {}
      Zip::File.open_buffer(archive) do |zip|
        zip.each do |entry|
          entries[entry.name] = entry.get_input_stream.read
        end
      end
      entries
    end
end
