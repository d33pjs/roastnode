require "test_helper"

class PreparationToolsControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace tools only" do
    sign_in_as(users(:one))
    preparation_tools(:wdt).update!(position: 20)
    preparation_tools(:puck_screen).update!(position: 10)

    get preparation_tools_path

    assert_response :success
    assert_select "h1", I18n.t("preparation_tools.index.title")
    assert_select "[data-testid=preparation-tool-card-list]"
    assert_select "a#preparation_tool_#{preparation_tools(:wdt).id}[data-testid=preparation-tool-card][href=?]",
      preparation_tool_path(preparation_tools(:wdt)),
      text: /#{preparation_tools(:wdt).name}/
    assert_appears_before preparation_tool_path(preparation_tools(:puck_screen)), preparation_tool_path(preparation_tools(:wdt))
    assert_select "table", count: 0
    assert_select "body", text: preparation_tools(:other_workspace_tool).name, count: 0
  end

  test "index renders primary preparation tool photo" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    first = attach_photo(tool)
    primary = attach_photo(tool)
    tool.set_primary_photo!(primary)

    get preparation_tools_path

    assert_response :success
    assert_select "img[data-testid=preparation-tool-card-photo][src=?]", media_attachment_path(primary, variant: :thumbnail)
    assert_select "img[data-testid=preparation-tool-card-photo][src=?]", media_attachment_path(first, variant: :thumbnail), count: 0
  end

  test "show renders tool details photos and usage" do
    sign_in_as(users(:one))
    attachment = attach_photo(preparation_tools(:wdt))

    get preparation_tool_path(preparation_tools(:wdt))

    assert_response :success
    assert_select "h1", preparation_tools(:wdt).name
    assert_select "[data-testid=preparation-tool-status]", I18n.t("preparation_tools.show.active")
    assert_select "[data-testid=preparation-tool-brew-count]", "1"
    assert_select "[data-testid=preparation-tool-total-ground]", "18g"
    assert_select "[data-testid=preparation-tool-channeling-rate]", "0%"
    assert_select "[data-testid=preparation-tool-recent-brews] a[href=?]", brew_path(brews(:morning_espresso))
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
    assert_select "a[href=?]", edit_preparation_tool_path(preparation_tools(:wdt)), text: I18n.t("preparation_tools.show.edit")
    assert_select "form[action=?]", archive_preparation_tool_path(preparation_tools(:wdt))
    assert_select "[data-testid=preparation-tool-danger-zone]"
    assert_select "form[action=?]", preparation_tool_path(preparation_tools(:wdt))
  end

  test "show renders preparation tool record links" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    tool.record_links.create!(label: "Tool info", url: "https://example.test/tool", kind: "info", visibility: "public")

    get preparation_tool_path(tool)

    assert_response :success
    assert_select "[data-testid=record-links-list]"
    assert_select "a[href='https://example.test/tool']", text: /Tool info/
  end

  test "show filters preparation tool analytics by date range" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
    old_brew = beans(:open_household).brews.create!(
      workspace: tool.workspace,
      user: users(:one),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 20, 8, 15, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 45,
      rating: 3,
      channeling: true
    )
    old_brew.brew_preparation_tools.create!(
      preparation_tool: tool,
      tool_name: tool.name,
      brew_method: tool.brew_method,
      position: 0
    )

    get preparation_tool_path(tool), params: { start_date: "2026-05-26", end_date: "2026-05-26" }

    assert_response :success
    assert_select "input[data-testid=preparation-tool-statistics-start-date][value='2026-05-26']"
    assert_select "input[data-testid=preparation-tool-statistics-end-date][value='2026-05-26']"
    assert_select "[data-testid=preparation-tool-brew-count]", "1"
    assert_select "[data-testid=preparation-tool-total-ground]", "18g"
    assert_select "[data-testid=preparation-tool-channeling-rate]", "0%"
    assert_select "[data-testid=preparation-tool-recent-brews] a[href=?]", brew_path(brews(:morning_espresso))
    assert_select "[data-testid=preparation-tool-recent-brews] a[href=?]", brew_path(old_brew), count: 0
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get preparation_tool_path(preparation_tools(:other_workspace_tool))

    assert_response :not_found
  end

  test "new shows photo upload" do
    sign_in_as(users(:one))

    get new_preparation_tool_path

    assert_response :success
    assert_select "[data-testid=preparation-tool-form-section][data-section=identity]"
    assert_select "[data-testid=preparation-tool-form-section][data-section=setup]"
    assert_select "[data-testid=preparation-tool-form-section][data-section=notes]"
    assert_select "input[type=file][name=?][multiple=multiple]", "preparation_tool[photos][]"
  end

  test "admin can create preparation tool" do
    admin = User.create!(email_address: "tool-admin@example.com", password: "password")
    Membership.create!(workspace: workspaces(:household), user: admin, role: :admin)
    admin.update!(active_workspace: workspaces(:household))
    sign_in_as(admin)

    assert_difference -> { workspaces(:household).preparation_tools.count }, 1 do
      post preparation_tools_path, params: {
        preparation_tool: {
          name: "Paper filter",
          brew_method: "espresso",
          notes: "Bottom filter",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to preparation_tools_path
    tool = workspaces(:household).preparation_tools.order(:created_at).last
    assert_equal "Paper filter", tool.name
    assert_equal 1, tool.photos.count
    assert_equal 30, tool.position
  end

  test "member can view preparation tools but cannot manage them" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    tool = preparation_tools(:wdt)

    get preparation_tools_path
    assert_response :success
    assert_select "a[href=?]", new_preparation_tool_path, count: 0

    get preparation_tool_path(tool)
    assert_response :success
    assert_select "h1", tool.name
    assert_select "a[href=?]", edit_preparation_tool_path(tool), count: 0
    assert_select "form[action=?]", archive_preparation_tool_path(tool), count: 0
    assert_select "[data-testid=preparation-tool-danger-zone]", count: 0

    assert_no_difference -> { workspaces(:household).preparation_tools.count } do
      post preparation_tools_path, params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    end
    assert_redirected_to root_path

    get edit_preparation_tool_path(tool)
    assert_redirected_to root_path

    patch preparation_tool_path(tool), params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    assert_redirected_to root_path
    assert_not_equal "Nope", tool.reload.name

    patch archive_preparation_tool_path(tool)
    assert_redirected_to root_path
    assert tool.reload.active?

    delete preparation_tool_path(tool)
    assert_redirected_to root_path
    assert PreparationTool.exists?(tool.id)
  end

  test "edit renders current photos and update adds photos" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    existing_photo = attach_photo(tool)

    get edit_preparation_tool_path(tool)

    assert_response :success
    assert_select "h1", I18n.t("preparation_tools.edit.title")
    assert_select "img[src=?]", media_attachment_path(existing_photo, variant: :thumbnail)
    assert_select "input[name=?][value=?]", "preparation_tool[position]", tool.position.to_s
    assert_select "input[type=file][name=?][multiple=multiple]", "preparation_tool[photos][]"

    assert_difference -> { tool.reload.photos.count }, 1 do
      patch preparation_tool_path(tool), params: {
        preparation_tool: {
          name: "Precision WDT",
          brew_method: "espresso",
          notes: "Nine needles.",
          position: "12",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to preparation_tool_path(tool)
    assert_equal "Precision WDT", tool.reload.name
    assert_equal "Nine needles.", tool.notes
    assert_equal 12, tool.position
  end

  test "admin can edit preparation tool public note and public links" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)

    get edit_preparation_tool_path(tool)

    assert_response :success
    assert_select "textarea[name=?]", "preparation_tool[public_note]"
    assert_select "[data-testid=record-links-fields]"

    patch preparation_tool_path(tool), params: {
      preparation_tool: {
        name: tool.name,
        brew_method: tool.brew_method,
        position: tool.position,
        public_note: "Public WDT note.",
        record_links_attributes: {
          "0" => {
            label: "Tool info",
            url: "https://example.com/wdt",
            kind: "info",
            visibility: "public",
            position: "10"
          }
        }
      }
    }

    assert_redirected_to preparation_tool_path(tool)
    assert_equal "Public WDT note.", tool.reload.public_note
    assert_equal "Tool info", tool.record_links.first.label
  end

  test "archive and reopen preparation tool" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)

    patch archive_preparation_tool_path(tool)

    assert_redirected_to preparation_tool_path(tool)
    assert_not tool.reload.active?

    patch reopen_preparation_tool_path(tool)

    assert_redirected_to preparation_tool_path(tool)
    assert tool.reload.active?
  end

  test "destroy removes preparation tool without deleting brew snapshots" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    snapshot = brew_preparation_tools(:morning_espresso_wdt)

    assert_difference -> { workspaces(:household).preparation_tools.count }, -1 do
      assert_no_difference -> { Brew.count } do
        assert_no_difference -> { BrewPreparationTool.count } do
          delete preparation_tool_path(tool)
        end
      end
    end

    assert_redirected_to preparation_tools_path
    assert_nil snapshot.reload.preparation_tool
    assert_equal "WDT", snapshot.tool_name
  end

  test "viewer cannot manage preparation tool" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    tool = preparation_tools(:wdt)

    get edit_preparation_tool_path(tool)
    assert_redirected_to root_path

    patch preparation_tool_path(tool), params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    assert_redirected_to root_path

    patch archive_preparation_tool_path(tool)
    assert_redirected_to root_path

    delete preparation_tool_path(tool)
    assert_redirected_to root_path
    assert tool.reload.active?
  ensure
    memberships(:member)&.update!(role: "member")
  end

  test "viewer cannot create preparation tool" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).preparation_tools.count } do
      post preparation_tools_path, params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    end

    assert_redirected_to root_path
  end

  private
    def assert_appears_before(first_text, second_text)
      first_index = response.body.index(first_text)
      second_index = response.body.index(second_text)

      assert first_index.present?, "Expected #{first_text.inspect} to appear in the response"
      assert second_index.present?, "Expected #{second_text.inspect} to appear in the response"
      assert_operator first_index, :<, second_index
    end
end
