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
  end

  test "unknown actions fail closed" do
    event = ActivityEvent.new(action: "future.unknown", metadata: { "actor_label" => "Jens" })
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "Unknown activity", presenter.summary
    assert_equal "more_vert", presenter.icon
    assert_nil presenter.path
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
