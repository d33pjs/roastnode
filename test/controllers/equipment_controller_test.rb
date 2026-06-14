require "test_helper"

class EquipmentControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace equipment only" do
    sign_in_as(users(:one))

    get equipment_index_path

    assert_response :success
    assert_select "h1", I18n.t("equipment.index.title")
    assert_select "[data-testid=equipment-card-list]"
    assert_select "a[data-testid=equipment-card][href=?]", equipment_path(equipment(:household_grinder)), text: /#{equipment(:household_grinder).name}/
    assert_select "table", count: 0
    assert_select "body", text: equipment(:other_workspace_grinder).name, count: 0
  end

  test "index renders primary equipment photo" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    first = attach_photo(grinder)
    primary = attach_photo(grinder)
    grinder.set_primary_photo!(primary)

    get equipment_index_path

    assert_response :success
    assert_select "img[data-testid=equipment-card-photo][src=?]", media_attachment_path(primary, variant: :thumbnail)
    assert_select "img[data-testid=equipment-card-photo][src=?]", media_attachment_path(first, variant: :thumbnail), count: 0
  end

  test "admin can create equipment" do
    admin = User.create!(email_address: "gear-admin@example.com", password: "password")
    Membership.create!(workspace: workspaces(:household), user: admin, role: :admin)
    admin.update!(active_workspace: workspaces(:household))
    sign_in_as(admin)

    assert_difference -> { workspaces(:household).equipment.count }, 1 do
      post equipment_index_path, params: {
        equipment: {
          name: "Eureka Mignon",
          kind: "grinder",
          model: "Specialita",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to gear_path
    equipment = workspaces(:household).equipment.order(:created_at).last
    assert_equal "grinder", equipment.kind
    assert_equal 1, equipment.photos.count
  end

  test "new includes photo upload" do
    sign_in_as(users(:one))

    get new_equipment_path

    assert_response :success
    assert_select "[data-testid=equipment-form-section][data-section=identity]"
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      gear_path,
      I18n.t("equipment.new.back"),
      I18n.t("equipment.new.back")
    assert_select "[data-testid=equipment-form-section][data-section=setup]"
    assert_select "[data-testid=equipment-form-section][data-section=notes]"
    assert_select "input[type=file][name=?][multiple=multiple]", "equipment[photos][]"
  end

  test "new equipment can preselect brewer kind" do
    sign_in_as(users(:one))

    get new_equipment_path(kind: "brewer")

    assert_response :success
    assert_select "select[name=?] option[value=brewer][selected]", "equipment[kind]"
  end

  test "edit renders current photos and updates equipment with added photos" do
    sign_in_as(users(:one))
    equipment = equipment(:household_grinder)
    existing_photo = attach_photo(equipment)

    get edit_equipment_path(equipment)

    assert_response :success
    assert_select "h1", I18n.t("equipment.edit.title")
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      gear_path,
      I18n.t("equipment.edit.back"),
      I18n.t("equipment.edit.back")
    assert_select "img[src=?]", media_attachment_path(existing_photo, variant: :thumbnail)
    assert_select "input[type=file][name=?][multiple=multiple]", "equipment[photos][]"

    assert_difference -> { equipment.reload.photos.count }, 1 do
      patch equipment_path(equipment), params: {
        equipment: {
          name: "Eureka Atom",
          kind: "grinder",
          model: "Atom 75",
          notes: "Single dosing setup.",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to gear_path
    assert_equal "Eureka Atom", equipment.reload.name
    assert_equal "Atom 75", equipment.model
    assert_equal "Single dosing setup.", equipment.notes
  end

  test "admin can edit equipment public note and public links" do
    sign_in_as(users(:one))
    equipment = equipment(:household_grinder)

    get edit_equipment_path(equipment)

    assert_response :success
    assert_select "textarea[name=?]", "equipment[public_note]"
    assert_select "[data-testid=record-links-fields]"

    patch equipment_path(equipment), params: {
      equipment: {
        name: equipment.name,
        kind: equipment.kind,
        model: equipment.model,
        public_note: "Public grinder note.",
        record_links_attributes: {
          "0" => {
            label: "Buy grinder",
            url: "https://example.com/grinder",
            kind: "affiliate",
            visibility: "public",
            position: "10"
          }
        }
      }
    }

    assert_redirected_to gear_path
    assert_equal "Public grinder note.", equipment.reload.public_note
    assert_equal "Buy grinder", equipment.record_links.first.label
  end

  test "updating equipment refreshes public bean share snapshots" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    share = create_public_bean_share_for(beans(:open_household))

    patch equipment_path(grinder), params: {
      equipment: {
        name: "Updated Niche",
        kind: grinder.kind,
        model: "Updated Zero"
      }
    }

    assert_redirected_to gear_path
    equipment_names = snapshot_equipment_names(share)
    assert_includes equipment_names, "Updated Niche"
    assert_not_includes equipment_names, "Niche Zero"
  end

  test "viewer cannot create equipment" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).equipment.count } do
      post equipment_index_path, params: { equipment: { name: "Nope", kind: "machine" } }
    end

    assert_redirected_to root_path
  end

  test "member can view equipment but cannot manage it" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    equipment = equipment(:household_grinder)

    get equipment_index_path
    assert_response :success
    assert_select "a[href=?]", new_equipment_path, count: 0

    get equipment_path(equipment)
    assert_response :success
    assert_select "h1", equipment.name
    assert_select "a[href=?]", edit_equipment_path(equipment), count: 0
    assert_select "form[action=?]", archive_equipment_path(equipment), count: 0
    assert_select "[data-testid=equipment-danger-zone]", count: 0

    assert_no_difference -> { workspaces(:household).equipment.count } do
      post equipment_index_path, params: { equipment: { name: "Nope", kind: "machine" } }
    end
    assert_redirected_to root_path

    get edit_equipment_path(equipment)
    assert_redirected_to root_path

    patch equipment_path(equipment), params: { equipment: { name: "Nope", kind: "grinder" } }
    assert_redirected_to root_path
    assert_not_equal "Nope", equipment.reload.name

    patch archive_equipment_path(equipment)
    assert_redirected_to root_path
    assert_not equipment.reload.archived?

    delete equipment_path(equipment)
    assert_redirected_to root_path
    assert Equipment.exists?(equipment.id)
  end

  test "show lists active workspace equipment activity" do
    sign_in_as(users(:one))

    get equipment_path(equipment(:household_grinder))

    assert_response :success
    assert_select "h1", equipment(:household_grinder).name
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      gear_path,
      I18n.t("equipment.show.back"),
      I18n.t("equipment.show.back")
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "p", text: /18g/
  end

  test "show exposes equipment management and danger zone actions" do
    sign_in_as(users(:one))
    equipment = equipment(:household_grinder)

    get equipment_path(equipment)

    assert_response :success
    header = Nokogiri::HTML(response.body).at_css("[data-testid='equipment-detail-header-controls']")
    assert_not_includes header["class"].to_s, "flex-col"
    assert_select "[data-testid=equipment-detail-actions] a[href=?][title=?]",
      edit_equipment_path(equipment),
      I18n.t("equipment.show.edit")
    assert_select "[data-testid=equipment-detail-actions] svg.material-symbol[data-symbol=edit]"
    assert_select "a[href=?]", new_equipment_event_path, count: 0
    assert_select "form[action=?]", archive_equipment_path(equipment)
    assert_select "[data-testid=equipment-danger-zone]"
    assert_select "form[action=?]", equipment_path(equipment)
    assert_appears_before "data-testid=\"equipment-recent-brews\"", "data-testid=\"equipment-danger-zone\""
  end

  test "show renders equipment record links" do
    sign_in_as(users(:one))
    equipment = equipment(:household_grinder)
    equipment.record_links.create!(label: "Buy grinder", url: "https://example.test/grinder", kind: "buy", visibility: "public")

    get equipment_path(equipment)

    assert_response :success
    assert_select "[data-testid=record-links-list]"
    assert_select "a[href='https://example.test/grinder']", text: /Buy grinder/
  end

  test "archive and reopen equipment" do
    sign_in_as(users(:one))
    equipment = equipment(:household_grinder)

    patch archive_equipment_path(equipment)

    assert_redirected_to gear_path
    assert equipment.reload.archived?

    patch reopen_equipment_path(equipment)

    assert_redirected_to gear_path
    assert_not equipment.reload.archived?
  end

  test "destroy removes equipment without deleting brew history" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    brew = brews(:morning_espresso)
    share = create_public_brew_share_for(brew)
    bean_share = create_public_bean_share_for(brew.bean)
    assert_equal grinder.name, share.snapshot.dig("equipment", 0, "name")
    assert_includes snapshot_equipment_names(bean_share), grinder.name

    assert_difference -> { workspaces(:household).equipment.count }, -1 do
      assert_no_difference -> { Brew.count } do
        delete equipment_path(grinder)
      end
    end

    assert_redirected_to gear_path
    assert_nil brew.reload.grinder
    assert_not_includes share.reload.snapshot.fetch("equipment").map { |item| item.fetch("role") }, "grinder"
    assert_not_includes snapshot_equipment_names(bean_share), grinder.name
  end

  test "viewer cannot manage equipment" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    equipment = equipment(:household_grinder)

    get edit_equipment_path(equipment)
    assert_redirected_to root_path

    patch equipment_path(equipment), params: { equipment: { name: "Nope", kind: "grinder" } }
    assert_redirected_to root_path

    patch archive_equipment_path(equipment)
    assert_redirected_to root_path

    delete equipment_path(equipment)
    assert_redirected_to root_path
    assert Equipment.exists?(equipment.id)
  end

  test "show renders usage analytics" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    brew = beans(:open_household).brews.create!(
      workspace: grinder.workspace,
      user: users(:one),
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 25, 8, 15, 0),
      bean_weight_grams: 19,
      ground_weight_grams: 19,
      dose_grams: 19,
      beverage_grams: 45,
      rating: 5,
      channeling: true
    )

    get equipment_path(grinder)

    assert_response :success
    assert_select "h2", I18n.t("equipment.show.analytics")
    assert_select "[data-testid=equipment-total-brews]", "2"
    assert_select "[data-testid=equipment-total-ground]", "37g"
    assert_select "[data-testid=equipment-channeling-rate]", "50%"
    assert_select "[data-testid=equipment-brews-since-service]"
    assert_select "[data-testid=equipment-grams-since-service]"
    assert_select "[data-testid=equipment-recent-brews] a[href=?]", brew_path(brew), text: /House Blend/
    assert_select "h3", I18n.t("equipment.show.brews_by_day")
    assert_select "h3", I18n.t("equipment.show.maintenance_markers")
    assert_select "body", text: /Other Grinder/, count: 0
  end

  test "show filters equipment analytics by date range" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    bean = beans(:open_household)
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
    bean.brews.create!(
      workspace: grinder.workspace,
      user: users(:one),
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 20, 8, 15, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 45,
      rating: 3,
      channeling: true
    )

    get equipment_path(grinder), params: { start_date: "2026-05-26", end_date: "2026-05-26" }

    assert_response :success
    assert_select "input[data-testid=equipment-statistics-start-date][value='2026-05-26']"
    assert_select "input[data-testid=equipment-statistics-end-date][value='2026-05-26']"
    assert_select "[data-testid=equipment-total-brews]", "1"
    assert_select "[data-testid=equipment-total-ground]", "18g"
    assert_select "[data-testid=equipment-recent-brews] a[href=?]", brew_path(brews(:morning_espresso)), text: /House Blend/
    assert_select "[data-testid=equipment-recent-brews] a[href=?]", brew_path(Brew.order(:created_at).last), count: 0
  end

  test "show hides channeling analytics for brewer equipment without espresso data" do
    sign_in_as(users(:one))
    brewer = equipment(:household_brewer)
    brew = beans(:open_household).brews.create!(
      workspace: brewer.workspace,
      user: users(:one),
      method: "quick_drip",
      brewer:,
      machine_cups: 6,
      coffee_spoons: 6,
      channeling: true
    )

    get equipment_path(brewer)

    assert_response :success
    assert_select "[data-testid=equipment-total-brews]", "1"
    assert_select "[data-testid=equipment-total-ground]", "30g"
    assert_select "[data-testid=equipment-channeling-rate]", count: 0
    assert_select "[data-testid=equipment-recent-brews] a[href=?]", brew_path(brew), text: /House Blend/
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(equipment(:household_grinder))

    get equipment_path(equipment(:household_grinder))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get equipment_path(equipment(:other_workspace_grinder))

    assert_response :not_found
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end

    def create_public_brew_share_for(brew, selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids:
        ).call
      )
    end

    def create_public_bean_share_for(bean)
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def snapshot_equipment_names(share)
      share.reload.snapshot.fetch("brews").flat_map do |brew|
        brew.fetch("equipment", {}).values.map { |equipment| equipment["name"] }
      end
    end
end
