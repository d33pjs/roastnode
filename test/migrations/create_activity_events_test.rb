require "test_helper"
require Rails.root.join("db/migrate/20260821120000_create_activity_events")

class CreateActivityEventsTest < ActiveSupport::TestCase
  test "backfill includes only reconstructable rows with truthful actors and times" do
    users(:one).update_column(:display_name, "Jens")
    recipe = recipes(:household_recipe)
    external_coffee = ExternalCoffee.create!(
      workspace: workspaces(:household), user: users(:one), drink_type: "Flat White",
      occurred_at: Time.zone.local(2026, 8, 20, 9)
    )
    manual_adjustment = InventoryAdjustment.create!(
      workspace: workspaces(:household), bean: beans(:open_household), user: users(:one),
      reason: "manual", delta_grams: 5, occurred_at: Time.zone.local(2026, 8, 20, 10)
    )
    brew_share = PublicBrewShare.create!(
      workspace: workspaces(:household), brew: brews(:morning_espresso), created_by: users(:two), updated_by: users(:two),
      title: "Historical brew share", enabled: true, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11), updated_at: Time.zone.local(2026, 8, 20, 11)
    )
    bean_share = PublicBeanShare.create!(
      workspace: workspaces(:household), bean: beans(:open_household), created_by: users(:two), updated_by: users(:two),
      title: "Historical bean share", enabled: false, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11, 15), updated_at: Time.zone.local(2026, 8, 20, 11, 15)
    )
    recipe_share = PublicRecipeShare.create!(
      workspace: workspaces(:household), recipe:, created_by: users(:two), updated_by: users(:two),
      title: "Historical recipe share", enabled: true, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11, 30), updated_at: Time.zone.local(2026, 8, 20, 11, 30)
    )
    completed_import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "completed",
      summary: { "beans" => { "created" => 1, "skipped" => 2 }, "brews" => { "created" => 3, "skipped" => 4 } },
      created_at: Time.zone.local(2026, 8, 20, 12), updated_at: Time.zone.local(2026, 8, 20, 12, 30)
    )
    failed_import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "failed",
      summary: { "beans" => { "created" => 0 } }
    )
    ActivityEvent.delete_all

    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.zone.local(2026, 8, 21, 12))
    migration.send(:backfill_brews)
    migration.send(:backfill_external_coffees)
    migration.send(:backfill_manual_adjustments)
    migration.send(:backfill_equipment_events)
    migration.send(:backfill_recipes)
    migration.send(:backfill_public_shares)
    migration.send(:backfill_completed_imports)

    brew_event = assert_backfill(
      action: "brew.created", subject: brews(:morning_espresso), actor: users(:one),
      occurred_at: brews(:morning_espresso).occurred_at
    )
    assert_equal "Jens", brew_event.metadata.fetch("actor_label")
    assert_backfill(action: "external_coffee.created", subject: external_coffee, actor: users(:one), occurred_at: external_coffee.occurred_at)
    assert_backfill(action: "inventory_adjustment.created", subject: manual_adjustment, actor: users(:one), occurred_at: manual_adjustment.occurred_at)
    assert_backfill(
      action: "equipment_event.created", subject: equipment_events(:grinder_cleaning), actor: users(:one),
      occurred_at: equipment_events(:grinder_cleaning).occurred_at
    )
    assert_backfill(action: "recipe.created", subject: recipe, actor: recipe.created_by, occurred_at: recipe.created_at)
    assert_backfill(action: "public_brew_share.created", subject: brew_share, actor: users(:two), occurred_at: brew_share.created_at)
    assert_backfill(action: "public_bean_share.created", subject: bean_share, actor: users(:two), occurred_at: bean_share.created_at)
    assert_backfill(action: "public_recipe_share.created", subject: recipe_share, actor: users(:two), occurred_at: recipe_share.created_at)
    import_event = assert_backfill(
      action: "data_import.completed", subject: completed_import, actor: users(:one), occurred_at: completed_import.updated_at
    )
    assert_equal 4, import_event.metadata.fetch("created_count")
    assert_equal 6, import_event.metadata.fetch("skipped_count")
    assert_not ActivityEvent.exists?(
      subject_type: "InventoryAdjustment", subject_id: inventory_adjustments(:morning_espresso_consumption).id
    ), "reason:brew inventory rows are implementation details, not manual activity"
    assert_not ActivityEvent.exists?(subject_type: "DataImport", subject_id: failed_import.id)
  end

  test "backfill sanitizes every scalar and array element from hostile fixture-backed legacy rows" do
    user = users(:one)
    brew = brews(:morning_espresso)
    bean = brew.bean
    equipment = equipment(:household_grinder)
    maintenance = equipment_events(:grinder_cleaning)
    user.update_column(:display_name, "token=legacy-actor-secret")
    bean.update_column(:name, "https://private.example/bean")
    brew.update_column(:method, "file_path=/private/brew")
    equipment.update_column(:name, "filename=legacy-photo.jpg")
    maintenance.update_columns(event_type: "other", event_types: [ "error=database details", "/private/equipment" ])
    ActivityEvent.delete_all

    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.current)
    migration.send(:backfill_brews)
    migration.send(:backfill_equipment_events)

    brew_metadata = ActivityEvent.find_by!(action: "brew.created", subject_id: brew.id).metadata
    assert_equal "[redacted]", brew_metadata.fetch("actor_label")
    assert_equal "[redacted]", brew_metadata.fetch("subject_label")
    assert_equal "[redacted]", brew_metadata.fetch("method")
    maintenance_metadata = ActivityEvent.find_by!(action: "equipment_event.created", subject_id: maintenance.id).metadata
    assert_equal [ "[redacted]", "[redacted]" ], maintenance_metadata.fetch("event_types")
    assert_includes maintenance_metadata.fetch("equipment_labels"), "[redacted]"
    assert_no_match(
      /legacy-actor-secret|private\.example|private\/brew|database details|private\/equipment|legacy-photo/i,
      ActivityEvent.pluck(:metadata).to_json
    )
  end

  test "backfill does not invent history and metadata contains no secrets" do
    ActivityEvent.delete_all
    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.current)
    migration.send(:backfill_brews)
    migration.send(:backfill_external_coffees)
    migration.send(:backfill_manual_adjustments)
    migration.send(:backfill_equipment_events)
    migration.send(:backfill_recipes)
    migration.send(:backfill_public_shares)
    migration.send(:backfill_completed_imports)

    assert_not ActivityEvent.exists?(subject_type: "Bean")
    assert_not ActivityEvent.exists?(subject_type: "Equipment")
    assert_not ActivityEvent.exists?(subject_type: "PreparationTool")
    assert_not ActivityEvent.exists?(subject_type: "Membership")
    payload = ActivityEvent.pluck(:metadata).to_json
    assert_no_match(/@/, payload)
    assert_no_match(/password|digest|token|session|signed_id|attachment|filename|https?:\/\/|\/storage\//i, payload)
    assert_no_match(/Found extra beans|Private/i, payload)
  end

  private
    def assert_backfill(action:, subject:, actor:, occurred_at:)
      event = ActivityEvent.find_by!(action:, subject_type: subject.class.base_class.name, subject_id: subject.id)
      assert_equal actor, event.actor
      assert_equal occurred_at.to_i, event.occurred_at.to_i
      event
    end
end
