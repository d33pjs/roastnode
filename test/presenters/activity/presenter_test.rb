require "test_helper"

class Activity::PresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "uses snapshotted Quick Drip copy and links a live subject" do
    event = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.created",
      occurred_at: Time.zone.local(2026, 8, 21, 9), visibility: "workspace",
      subject: brews(:morning_espresso),
      metadata: {
        "actor_kind" => "system", "actor_label" => "System", "record_kind" => "brew",
        "subject_label" => "Quick Drip with Filter Beans", "method" => "quick_drip"
      }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "System logged Quick Drip with Filter Beans", presenter.summary
    assert_equal "local_cafe", presenter.icon
    assert_equal brew_path(brews(:morning_espresso)), presenter.path
  end

  test "marks privileged rows and keeps deleted subjects unlinked" do
    presenter = Activity::Presenter.new(activity_events(:workspace_invite_created), helpers: self)

    assert_predicate presenter, :restricted?
    assert_nil presenter.path
    assert_equal "more_vert", presenter.icon
  end

  test "unknown and category-mismatched actions fail closed with neutral presentation" do
    event = ActivityEvent.new(
      category: "coffee", action: "future.unknown", metadata: { "actor_label" => "Jens" }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "Unknown activity", presenter.summary
    assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
    assert_equal "more_vert", presenter.icon
    assert_equal Activity::Presenter::NEUTRAL_ICON_CLASSES, presenter.icon_container_classes
    assert_nil presenter.path

    mismatched = ActivityEvent.new(
      category: "coffee", action: "bean.created", metadata: { "actor_label" => "Jens" }
    )
    presenter = Activity::Presenter.new(mismatched, helpers: self)

    assert_equal "Unknown activity", presenter.summary
    assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
    assert_equal "more_vert", presenter.icon
    assert_equal Activity::Presenter::NEUTRAL_ICON_CLASSES, presenter.icon_container_classes
    assert_nil presenter.path
  end

  test "recognized legacy rows missing required summary metadata fail closed" do
    event = ActivityEvent.new(
      category: "household_administration",
      action: "membership.role_changed",
      visibility: "workspace_admin",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "subject_label" => "Petra" }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal I18n.t("activity.events.unknown"), presenter.summary
    assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
    assert_equal "more_vert", presenter.icon
    assert_equal Activity::Presenter::NEUTRAL_ICON_CLASSES, presenter.icon_container_classes
    assert_nil presenter.path
  end

  test "legacy rows with non-object metadata fail closed" do
    [ nil, "scalar", [ "not-a-pair" ] ].each do |metadata|
      event = ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace", subject: brews(:morning_espresso), metadata:
      )
      presenter = Activity::Presenter.new(event, helpers: self)

      assert_equal I18n.t("activity.events.unknown"), presenter.summary
      assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
      assert_equal "more_vert", presenter.icon
      assert_equal Activity::Presenter::NEUTRAL_ICON_CLASSES, presenter.icon_container_classes
      assert_nil presenter.path
    end
  end

  test "legacy rows invalid under the full event contract fail closed" do
    safe_metadata = {
      "actor_kind" => "user", "actor_label" => "Jens", "subject_label" => "Coffee"
    }
    events = [
      ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace", subject: brews(:morning_espresso),
        metadata: safe_metadata.merge("actor_label" => "https://private.example/token=secret")
      ),
      ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace", subject: brews(:morning_espresso),
        metadata: safe_metadata.merge("actor_label" => "x" * (Activity::Metadata::MAX_TEXT + 1))
      ),
      ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace_admin", subject: brews(:morning_espresso),
        metadata: safe_metadata
      ),
      ActivityEvent.new(
        workspace: workspaces(:household), category: "beans_inventory", action: "bean.created",
        occurred_at: Time.current, visibility: "workspace", subject: brews(:morning_espresso),
        metadata: safe_metadata
      ),
      ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace", subject: brews(:other_workspace_brew),
        metadata: safe_metadata
      )
    ]

    events.each do |event|
      presenter = Activity::Presenter.new(event, helpers: self)

      assert_equal I18n.t("activity.events.unknown"), presenter.summary
      assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
      assert_equal "more_vert", presenter.icon
      assert_equal Activity::Presenter::NEUTRAL_ICON_CLASSES, presenter.icon_container_classes
      assert_nil presenter.path
    end
  end

  test "former member account activity keeps its summary but stays unlinked" do
    user = User.create!(
      email_address: "former-presenter-member@example.com",
      password: "password",
      display_name: "Former Presenter Member"
    )
    membership = workspaces(:household).memberships.create!(user:, role: "member")
    event = Activity::Emitter.record!(
      action: "profile.updated", workspace: workspaces(:household), actor: user, subject: user,
      occurred_at: Time.zone.local(2026, 8, 21, 11)
    )
    membership.destroy!
    presenter = Activity::Presenter.new(event.reload, helpers: self)

    assert_includes presenter.summary, "Former Presenter Member"
    assert_not_equal I18n.t("activity.events.unknown"), presenter.summary
    assert_nil presenter.path
  end

  test "unknown polymorphic subject types fail closed before constantization" do
    event = ActivityEvent.new(
      workspace: workspaces(:household), category: "coffee", action: "brew.created",
      occurred_at: Time.current, visibility: "workspace",
      subject_type: "FutureActivitySubject", subject_id: 123,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "subject_label" => "Unknown" }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal I18n.t("activity.events.unknown"), presenter.summary
    assert_equal I18n.t("activity.categories.unknown"), presenter.category_label
    assert_equal "more_vert", presenter.icon
    assert_nil presenter.path
  end

  test "recognized subjects without a safe private route use a tombstone presentation" do
    event = Activity::Emitter.record!(
      action: "workspace.updated", workspace: workspaces(:household), actor: users(:one),
      subject: workspaces(:household), occurred_at: Time.zone.local(2026, 8, 21, 10)
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_nil presenter.path
    assert_equal "more_vert", presenter.icon
  end

  test "presents and links External Coffee ledger events" do
    users(:one).update!(display_name: "Jens")
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one), drink_type: "Black Coffee", occurred_at: Time.zone.local(2026, 6, 9, 12)
    )
    event = Activity::Emitter.record!(
      action: "external_coffee.created", workspace: workspaces(:household), actor: users(:one),
      subject: coffee, occurred_at: coffee.occurred_at
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "Jens logged Black Coffee", presenter.summary
    assert_equal "local_cafe", presenter.icon
    assert_equal external_coffee_path(coffee), presenter.path
  end

  test "presents guest cupping activity with its private IP metadata" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    event = Activity::Emitter.record!(
      action: "brew.cupping_taste_changed", workspace: brew.workspace, subject: brew,
      actor_kind: "guest", actor_label: "Alex",
      details: { ip_address: "203.0.113.4", from_taste: "neutral", to_taste: "sour" }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "Alex changed the cupping taste for Espresso with #{brew.bean.name} for Alex from neutral to sour", presenter.summary
    assert_equal "203.0.113.4", presenter.ip_address
    assert_equal brew_path(brew), presenter.path
  end

  test "each category has a fixed distinguishable icon container" do
    coffee = Activity::Presenter.new(activity_events(:morning_brew_created), helpers: self)
    admin = Activity::Presenter.new(activity_events(:workspace_invite_created), helpers: self)

    assert_equal "bg-amber-100 text-amber-900", coffee.icon_container_classes
    assert_equal "bg-violet-100 text-violet-900", admin.icon_container_classes
    assert_not_equal coffee.icon_container_classes, admin.icon_container_classes
    assert_equal ActivityEvent::CATEGORIES.sort, Activity::Presenter::CATEGORY_ICON_CLASSES.keys.sort
    assert_equal ActivityEvent::CATEGORIES.size, Activity::Presenter::CATEGORY_ICON_CLASSES.values.uniq.size
  end
end
