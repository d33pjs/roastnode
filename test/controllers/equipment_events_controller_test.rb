require "test_helper"

class EquipmentEventsControllerTest < ActionDispatch::IntegrationTest
  test "new shows event form with active workspace equipment" do
    sign_in_as(users(:one))

    get new_equipment_event_path

    assert_response :success
    assert_select "h1", I18n.t("equipment_events.new.title")
    assert_select "input[type=checkbox][name=?][value=?]", "equipment_event[event_types][]", "grinder_cleaning"
    assert_select "input[type=checkbox][name=?][value=?]", "equipment_event[event_types][]", "machine_backflush"
    assert_select "input[type=checkbox][name=?][value=?]", "equipment_event[event_types][]", "brewer_cleaning"
    assert_select "input[type=checkbox][name=?][value=?]", "equipment_event[event_types][]", "brewer_descaling"
    assert_select "input[type=checkbox][name=?][value=?]", "equipment_event[event_types][]", "filter_change"
    assert_select "label", text: equipment(:household_grinder).name
    assert_select "label", text: equipment(:other_workspace_grinder).name, count: 0
    assert_select "input[type=file][name=?][multiple=multiple]", "equipment_event[photos][]"
  end

  test "new does not offer archived equipment" do
    archived = equipment(:household_grinder)
    archived.update!(archived_at: Time.current)
    sign_in_as(users(:one))

    get new_equipment_event_path

    assert_response :success
    assert_select "label", text: archived.name, count: 0
  end

  test "member can create equipment event" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).equipment_events.count }, 1 do
      assert_difference -> { EquipmentEventItem.count }, 1 do
        post equipment_events_path, params: {
          equipment_event: {
            event_types: [ "grinder_cleaning" ],
            occurred_at: "2026-05-26 08:30",
            notes: "Quick brush out.",
            equipment_ids: [ equipment(:household_grinder).id ],
            photos: [ photo_upload ]
          }
        }
      end
    end

    event = workspaces(:household).equipment_events.order(:created_at).last
    assert_redirected_to equipment_event_path(event)
    assert_equal user, event.user
    assert_includes event.equipment, equipment(:household_grinder)
    assert_equal 1, event.photos.count
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(equipment_events(:grinder_cleaning))

    get equipment_event_path(equipment_events(:grinder_cleaning))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
  end

  test "show exposes management and danger zone actions" do
    sign_in_as(users(:one))
    event = equipment_events(:grinder_cleaning)

    get equipment_event_path(event)

    assert_response :success
    header = Nokogiri::HTML(response.body).at_css("[data-testid='equipment-event-detail-header-controls']")
    assert_not_includes header["class"].to_s, "flex-col"
    assert_select "[data-testid=equipment-event-detail-actions] a[href=?][title=?]",
      edit_equipment_event_path(event),
      I18n.t("equipment_events.show.edit")
    assert_select "[data-testid=equipment-event-detail-actions] svg.material-symbol[data-symbol=edit]"
    assert_select "[data-testid=equipment-event-danger-zone]"
    assert_select "form[action=?]", equipment_event_path(event)
  end

  test "show links affected equipment to details" do
    event = equipment_events(:grinder_cleaning)
    sign_in_as(users(:one))

    get equipment_event_path(event)

    assert_response :success
    assert_select "[data-testid=equipment-event-equipment] a[href=?]", equipment_path(equipment(:household_grinder)),
      text: equipment(:household_grinder).name
  end

  test "show uses display label instead of email byline" do
    users(:one).update!(display_name: "Jens")
    sign_in_as(users(:one))

    get equipment_event_path(equipment_events(:grinder_cleaning))

    assert_response :success
    assert_select "p", text: I18n.t("equipment_events.show.byline", user: "Jens")
    assert_select "body", text: /one@example.com/, count: 0
  end

  test "member can create equipment event with multiple event types" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).equipment_events.count }, 1 do
      assert_difference -> { EquipmentEventItem.count }, 2 do
        post equipment_events_path, params: {
          equipment_event: {
            event_types: [ "grinder_cleaning", "machine_backflush" ],
            occurred_at: "2026-05-26 08:30",
            notes: "Cleaned both.",
            equipment_ids: [ equipment(:household_grinder).id, equipment(:household_machine).id ]
          }
        }
      end
    end

    event = workspaces(:household).equipment_events.order(:created_at).last
    assert_redirected_to equipment_event_path(event)
    assert_equal [ "grinder_cleaning", "machine_backflush" ], event.event_types
    assert_equal "grinder_cleaning", event.event_type
    assert_equal [ equipment(:household_grinder).id, equipment(:household_machine).id ].sort, event.equipment.ids.sort
  end

  test "member can create brewer equipment event" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).equipment_events.count }, 1 do
      assert_difference -> { EquipmentEventItem.count }, 1 do
        post equipment_events_path, params: {
          equipment_event: {
            event_types: [ "brewer_cleaning", "filter_change" ],
            occurred_at: "2026-05-26 08:30",
            notes: "Fresh filter and brewer rinse.",
            equipment_ids: [ equipment(:household_brewer).id ]
          }
        }
      end
    end

    event = workspaces(:household).equipment_events.order(:created_at).last
    assert_redirected_to equipment_event_path(event)
    assert_equal [ "brewer_cleaning", "filter_change" ], event.event_types
    assert_equal "brewer_cleaning", event.event_type
    assert_equal [ equipment(:household_brewer).id ], event.equipment.ids
  end

  test "edit renders current event values photos and affected equipment" do
    sign_in_as(users(:one))
    event = equipment_events(:grinder_cleaning)
    attachment = attach_photo(event)

    get edit_equipment_event_path(event)

    assert_response :success
    assert_select "h1", I18n.t("equipment_events.edit.title")
    assert_select "input[type=checkbox][name=?][value=?][checked]", "equipment_event[event_types][]", "grinder_cleaning"
    assert_select "input[type=checkbox][name=?][value=?][checked]", "equipment_event[equipment_ids][]", equipment(:household_grinder).id.to_s
    assert_select "textarea[name=?]", "equipment_event[notes]", text: event.notes
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
    assert_select "input[type=file][name=?][multiple=multiple]", "equipment_event[photos][]"
  end

  test "update changes event details equipment links and adds photos" do
    sign_in_as(users(:one))
    event = equipment_events(:grinder_cleaning)

    assert_difference -> { event.reload.photos.count }, 1 do
      patch equipment_event_path(event), params: {
        equipment_event: {
          event_types: [ "grinder_deep_cleaning", "burr_change" ],
          occurred_at: "2026-05-27 09:15",
          notes: "Deep clean with burr check.",
          equipment_ids: [ equipment(:household_grinder).id, equipment(:household_machine).id ],
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to equipment_event_path(event)
    assert_equal [ "grinder_deep_cleaning", "burr_change" ], event.reload.event_types
    assert_equal "grinder_deep_cleaning", event.event_type
    assert_equal "Deep clean with burr check.", event.notes
    assert_equal [ equipment(:household_grinder).id, equipment(:household_machine).id ].sort, event.equipment.ids.sort
  end

  test "destroy removes event and event item links" do
    sign_in_as(users(:one))
    event = equipment_events(:grinder_cleaning)
    equipment_count = workspaces(:household).equipment.count

    assert_difference -> { workspaces(:household).equipment_events.count }, -1 do
      assert_difference -> { EquipmentEventItem.count }, -1 do
        delete equipment_event_path(event)
      end
    end

    assert_redirected_to dashboard_path
    assert_equal equipment_count, workspaces(:household).equipment.count
  end

  test "viewer cannot create equipment event" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).equipment_events.count } do
      post equipment_events_path, params: {
        equipment_event: {
          event_types: [ "other" ],
          equipment_ids: [ equipment(:household_grinder).id ]
        }
      }
    end

    assert_redirected_to root_path
  end

  test "viewer cannot manage equipment event" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    event = equipment_events(:grinder_cleaning)

    get edit_equipment_event_path(event)
    assert_redirected_to root_path

    patch equipment_event_path(event), params: { equipment_event: { event_types: [ "other" ], equipment_ids: [ equipment(:household_grinder).id ] } }
    assert_redirected_to root_path

    delete equipment_event_path(event)
    assert_redirected_to root_path
    assert EquipmentEvent.exists?(event.id)
  ensure
    memberships(:member)&.update!(role: "member")
  end

  test "create rejects equipment from another workspace" do
    sign_in_as(users(:one))

    assert_no_difference -> { workspaces(:household).equipment_events.count } do
      post equipment_events_path, params: {
        equipment_event: {
          event_types: [ "grinder_cleaning" ],
          equipment_ids: [ equipment(:other_workspace_grinder).id ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", text: /must belong to the workspace/
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get equipment_event_path(equipment_events(:other_workspace_event))

    assert_response :not_found
  end
end
