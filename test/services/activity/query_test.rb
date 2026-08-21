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

  test "invalid filter values fail closed or are ignored without raising" do
    assert_empty query(category: "not-a-category").events
    assert_empty query(actor: "user:not-an-id").events
    assert query(start_date: "31/31/2026", end_date: "bad").events.exists?
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
