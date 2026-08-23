require "test_helper"

class Activity::QueryTest < ActiveSupport::TestCase
  def query(user: users(:one), membership: memberships(:owner), **filters)
    Activity::Query.new(workspace: workspaces(:household), membership:, user:, **filters)
  end

  test "viewer sees workspace rows but neither workspace-admin nor other-workspace rows" do
    membership = memberships(:owner)
    membership.update!(role: "viewer")

    actions = query(membership:).events.pluck(:action)

    assert_includes actions, "brew.created"
    assert_not_includes actions, "workspace_invite.created"
    assert_not ActivityEvent.where(id: query(membership:).events).exists?(workspace: workspaces(:other_household))
  end

  test "workspace admin sees workspace-admin rows" do
    memberships(:owner).update!(role: "admin")
    assert_includes query.events.pluck(:action), "workspace_invite.created"
  end

  test "a membership belonging to another user grants no workspace rows" do
    assert_empty query(user: users(:two), membership: memberships(:owner)).events
  end

  test "instance admins require a valid active-workspace membership for every activity scope" do
    user = users(:one)
    user.update!(instance_admin: true)

    [ nil, memberships(:other_owner), memberships(:member) ].each do |membership|
      invalid_query = query(user:, membership:)

      assert_empty invalid_query.events
      assert_empty invalid_query.actor_options
    end
  end

  test "instance admin receives instance rows but status alone never grants workspace-admin rows" do
    user = users(:one)
    user.update!(instance_admin: true)
    membership = memberships(:owner)
    membership.update!(role: "member")

    actions = query(user:, membership:).events.pluck(:action)

    assert_includes actions, "instance_backup_run.succeeded"
    assert_not_includes actions, "workspace_invite.created"
  end

  test "category actor and inclusive local dates combine without changing scope" do
    user = users(:one)
    user.update!(time_zone: "Europe/Berlin")
    event = Activity::Emitter.record!(
      action: "brew.created", workspace: workspaces(:household), actor: user,
      subject: brews(:morning_espresso), occurred_at: Time.utc(2026, 8, 20, 22)
    )
    excluded = Activity::Emitter.record!(
      action: "bean.created", workspace: workspaces(:household), actor: user,
      subject: beans(:open_household), occurred_at: Time.utc(2026, 8, 21, 22)
    )

    Time.use_zone(user.time_zone) do
      ids = query(
        user:, category: "coffee", actor: "user:#{user.id}",
        start_date: "2026-08-21", end_date: "2026-08-21"
      ).events.pluck(:id)
      assert_includes ids, event.id
      assert_not_includes ids, excluded.id
    end
  end

  test "includes External Coffee ledger events in the authorized workspace relation" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one), drink_type: "Black Coffee", occurred_at: Time.zone.local(2026, 6, 9, 12)
    )
    event = Activity::Emitter.record!(
      action: "external_coffee.created", workspace: workspaces(:household), actor: users(:one),
      subject: coffee, occurred_at: coffee.occurred_at
    )

    assert_includes query.events, event
  end

  test "actor options include former snapshots and system from authorized rows only" do
    former = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Former member" }
    )
    ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "system", "actor_label" => "System" }
    )

    options = query.actor_options.index_by(&:value)

    assert_equal "Jens", options.fetch("user:#{users(:one).id}").label
    former_value = "former:#{Base64.urlsafe_encode64('Former member', padding: false)}"
    assert_equal "Former member", options.fetch(former_value).label
    assert_equal "System", options.fetch("system").label
    assert_not_includes options.values.map(&:label), users(:two).email_address
  end

  test "actor options collapse duplicate ledger rows in SQL before materializing safe scalar labels" do
    now = Time.current
    3.times do |index|
      Activity::Emitter.record!(
        action: "brew.updated", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), occurred_at: now - index.seconds
      )
    end
    statements = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      statements << payload[:sql] if payload[:name] != "SCHEMA"
    end

    options = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { query.actor_options }
    actor_sql = statements.find { |sql| sql.match?(/FROM "activity_events"/i) }

    assert actor_sql, "expected the actor-option ledger query"
    assert_match(/SELECT DISTINCT ON/i, actor_sql)
    assert_equal 1, options.count { |option| option.value == "user:#{users(:one).id}" }
  end

  test "actor options fall back to the newest safe label when newer legacy labels are unsafe" do
    now = Time.current
    nonbreaking_space = "\u00A0"
    unsafe_labels = [
      nonbreaking_space,
      "#{nonbreaking_space}/private/actor",
      "https://private.example/token=abc",
      "unsafe\aactor",
      "/private/actor",
      "unsafe\u0085actor"
    ]
    safe_event = Activity::Emitter.record!(
      action: "brew.updated", workspace: workspaces(:household), actor: users(:one),
      subject: brews(:morning_espresso), occurred_at: now - unsafe_labels.length.seconds
    )
    ActivityEvent.insert_all!(unsafe_labels.each_with_index.map do |label, index|
      {
        workspace_id: workspaces(:household).id,
        actor_id: users(:one).id,
        category: "coffee",
        action: "brew.updated",
        occurred_at: now - index.seconds,
        visibility: "workspace",
        subject_type: "Brew",
        subject_id: brews(:morning_espresso).id,
        metadata: {
          "actor_kind" => "user",
          "actor_label" => label,
          "subject_label" => "Espresso with House Espresso",
          "method" => "espresso"
        },
        created_at: now,
        updated_at: now
      }
    end)

    option = query.actor_options.index_by(&:value).fetch("user:#{users(:one).id}")

    assert_equal safe_event.metadata.fetch("actor_label"), option.label
  end

  test "event presentation preloads workspaces direct subjects and nested path associations" do
    bean_event = Activity::Emitter.record!(
      action: "bean.created", workspace: workspaces(:household), actor: users(:one),
      subject: beans(:open_household)
    )
    adjustment_event = Activity::Emitter.record!(
      action: "inventory_adjustment.created", workspace: workspaces(:household), actor: users(:one),
      subject: inventory_adjustments(:morning_espresso_consumption)
    )
    account_event = Activity::Emitter.record!(
      action: "profile.updated", workspace: workspaces(:household), actor: users(:two),
      subject: users(:two)
    )
    event_ids = [ activity_events(:morning_brew_created).id, bean_event.id, adjustment_event.id, account_event.id ]
    events = query.recent_events(limit: 100).select { |event| event_ids.include?(event.id) }
    helpers = Object.new
    helpers.define_singleton_method(:brew_path) { |_record| "/brews/1" }
    helpers.define_singleton_method(:bean_path) { |_record| "/beans/1" }
    statements = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      statements << payload[:sql] if payload[:name] != "SCHEMA"
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      events.each { |event| Activity::Presenter.new(event, helpers:).path }
    end

    assert_equal 4, events.size
    assert_empty statements.grep(/\ASELECT/i), "expected card routes to use the bounded presentation preload"
  end

  test "subject preloading does not constantize an unknown legacy polymorphic type" do
    now = Time.current
    ActivityEvent.insert_all!([ {
      workspace_id: workspaces(:household).id,
      actor_id: users(:one).id,
      category: "coffee",
      action: "brew.created",
      occurred_at: now,
      visibility: "workspace",
      subject_type: "FutureActivitySubject",
      subject_id: 123,
      metadata: {
        "actor_kind" => "user",
        "actor_label" => "Jens",
        "subject_label" => "Future subject"
      },
      created_at: now,
      updated_at: now
    } ])

    assert_nothing_raised { query.recent_events(limit: 100) }
  end

  test "actor options omit a malformed legacy former actor without a label" do
    now = Time.current
    ActivityEvent.insert_all!([ {
      workspace_id: workspaces(:household).id,
      category: "coffee",
      action: "brew.updated",
      occurred_at: now,
      visibility: "workspace",
      metadata: { "actor_kind" => "user" },
      created_at: now,
      updated_at: now
    } ])

    options = query.actor_options

    assert_not options.any? { |option| option.value.start_with?("former:") && option.label.blank? }
  end

  test "actor options skip legacy non-object metadata" do
    now = Time.current
    rows = ActivityEvent.insert_all!([ {}, "scalar", [ "not-a-pair" ] ].map do |metadata|
      {
        workspace_id: workspaces(:household).id,
        category: "coffee",
        action: "brew.updated",
        occurred_at: now,
        visibility: "workspace",
        metadata:,
        created_at: now,
        updated_at: now
      }
    end, returning: %w[id])
    ActivityEvent.where(id: rows.rows.first.first).update_all(metadata: Arel.sql("'null'::jsonb"))

    options = query.actor_options

    assert options.any?
    assert options.all? { |option| option.label.present? }
  end

  test "actor options require an explicit actor kind" do
    now = Time.current
    ActivityEvent.insert_all!([
      {
        workspace_id: workspaces(:household).id,
        category: "coffee", action: "brew.updated", occurred_at: now,
        visibility: "workspace", metadata: { "actor_label" => "Poisoned system label" },
        created_at: now, updated_at: now
      },
      {
        workspace_id: workspaces(:household).id,
        category: "coffee", action: "brew.updated", occurred_at: now - 1.second,
        visibility: "workspace", metadata: { "actor_kind" => "system", "actor_label" => "System" },
        created_at: now, updated_at: now
      }
    ])

    options = query.actor_options.index_by(&:value)

    assert_equal "System", options.fetch("system").label
    assert_not_includes options.values.map(&:label), "Poisoned system label"
  end

  test "invalid filter values fail closed or are ignored without raising" do
    assert_empty query(category: "not-a-category").events
    assert_empty query(actor: "user:not-an-id").events
    assert query(start_date: "31/31/2026", end_date: "bad").events.exists?
  end

  test "former actor filter rejects invalid UTF-8 and NUL labels" do
    [ "\xFF".b, "\0" ].each do |label|
      selector = "former:#{Base64.urlsafe_encode64(label, padding: false)}"

      assert_empty query(actor: selector).events
    end
  end

  test "former actor filter rejects overlong and unsafe labels before querying" do
    labels = [ "x" * (Activity::Metadata::MAX_TEXT + 1), "https://private.example/token=abc" ]
    now = Time.current
    ActivityEvent.insert_all!(labels.map do |label|
      {
        workspace_id: workspaces(:household).id,
        category: "coffee",
        action: "brew.updated",
        occurred_at: now,
        visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => label },
        created_at: now,
        updated_at: now
      }
    end)

    labels.each do |label|
      selector = "former:#{Base64.urlsafe_encode64(label, padding: false)}"

      assert_empty query(actor: selector).events
    end
  end

  test "former and system actor selectors stay distinct when labels collide" do
    former = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "System" }
    )
    system = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "system", "actor_label" => "System" }
    )
    former_selector = "former:#{Base64.urlsafe_encode64('System', padding: false)}"

    former_ids = query(actor: former_selector).events.pluck(:id)
    system_ids = query(actor: "system").events.pluck(:id)

    assert_equal [ former.id ], former_ids
    assert_equal [ system.id ], system_ids
  end

  test "missing or cross-workspace membership grants no workspace rows" do
    assert_empty query(membership: nil).events
    assert_empty query(membership: memberships(:other_owner)).events
  end
end
