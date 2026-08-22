module ActivityEventTestHelper
  def assert_activity_events(actions:, workspace:, actor:)
    before_ids = ActivityEvent.pluck(:id)
    yield
    events = ActivityEvent.where.not(id: before_ids).order(:id).to_a
    assert_equal actions.sort, events.map(&:action).sort,
      "expected exact new activity action multiset #{actions.inspect}"
    events.each do |new_event|
      expected_workspace = workspace.respond_to?(:call) ? workspace.call : workspace
      expected_workspace ? assert_equal(expected_workspace, new_event.workspace) : assert_nil(new_event.workspace)
      expected_actor = actor.respond_to?(:call) ? actor.call : actor
      expected_actor ? assert_equal(expected_actor, new_event.actor) : assert_nil(new_event.actor)
    end
    events
  end

  def assert_activity_event(action:, workspace:, actor:, subject: nil, additional_actions: [])
    unknown_secondary_actions = Array(additional_actions) - [ "bean.used_up" ]
    assert_empty unknown_secondary_actions, "only bean.used_up is an approved secondary activity action"
    before_ids = ActivityEvent.pluck(:id)
    yield
    events = ActivityEvent.where.not(id: before_ids).order(:id).to_a
    expected_actions = [ action, *Array(additional_actions) ].sort
    assert_equal expected_actions, events.map(&:action).sort,
      "expected exact new activity action multiset #{expected_actions.inspect}"
    events.each do |new_event|
      expected_workspace = workspace.respond_to?(:call) ? workspace.call : workspace
      expected_workspace ? assert_equal(expected_workspace, new_event.workspace) : assert_nil(new_event.workspace)
      expected_actor = actor.respond_to?(:call) ? actor.call : actor
      expected_actor ? assert_equal(expected_actor, new_event.actor) : assert_nil(new_event.actor)
    end
    event = events.find { |new_event| new_event.action == action }
    assert_equal subject, event.subject if subject
    event
  end
end

ActiveSupport::TestCase.include ActivityEventTestHelper
