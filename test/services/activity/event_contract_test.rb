require "test_helper"
require Rails.root.join("test/support/activity_event_contract_coverage")

class Activity::EventContractTest < ActiveSupport::TestCase
  test "every action has one valid category visibility icon summary and override policy" do
    assert_equal Activity::EventContract.actions.uniq.sort, Activity::EventContract.actions.sort

    Activity::EventContract.actions.each do |action|
      definition = Activity::EventContract.fetch(action)
      assert_includes ActivityEvent::CATEGORIES, definition.fetch(:category), action
      assert_includes ActivityEvent::VISIBILITIES, definition.fetch(:visibility), action
      assert_includes definition.fetch(:visibilities), definition.fetch(:visibility), action
      assert definition.fetch(:visibilities).all? { |value| ActivityEvent::VISIBILITIES.include?(value) }, action
      assert definition.fetch(:subject_type).present?, action
      assert_equal(
        (definition.fetch(:automatic_metadata_keys) + definition.fetch(:detail_keys)).uniq.sort,
        definition.fetch(:metadata_keys).sort,
        action
      )
      assert ApplicationHelper::MATERIAL_SYMBOL_PATHS.key?(definition.fetch(:icon)), action
      assert I18n.exists?("activity.events.#{definition.fetch(:summary)}"), action
    end
  end

  test "only account actions can cross workspace-admin and instance-admin scope" do
    overridable = Activity::EventContract.actions.select do |action|
      Activity::EventContract.fetch(action).fetch(:visibilities).many?
    end

    assert_equal Activity::EventContract::ACCOUNT_ACTIONS.sort, overridable.sort
    assert overridable.all? do |action|
      Activity::EventContract.fetch(action).fetch(:visibilities).sort == %w[instance_admin workspace_admin]
    end
  end

  test "required metadata identifies actor and summary interpolation inputs" do
    assert_equal %w[actor_kind actor_label],
      Activity::EventContract.fetch("brew.created").fetch(:required_metadata_keys)
    assert_equal %w[actor_kind actor_label amount_grams],
      Activity::EventContract.fetch("inventory_adjustment.created").fetch(:required_metadata_keys)
    assert_equal %w[actor_kind actor_label from_role to_role],
      Activity::EventContract.fetch("membership.role_changed").fetch(:required_metadata_keys)
    assert_equal %w[actor_kind actor_label created_count skipped_count],
      Activity::EventContract.fetch("data_import.completed").fetch(:required_metadata_keys)
  end

  test "every summary interpolation input is schema defined and required" do
    Activity::EventContract.actions.each do |action|
      definition = Activity::EventContract.fetch(action)
      summary = I18n.t("activity.events.#{definition.fetch(:summary)}", locale: :en)
      metadata_placeholders = summary.scan(/%\{([^}]+)\}/).flatten - %w[actor subject]

      assert_empty metadata_placeholders.difference(definition.fetch(:metadata_schema).keys), action
      assert_empty metadata_placeholders.difference(definition.fetch(:required_metadata_keys)), action
    end
  end

  test "focused coverage scanner ignores a disconnected action literal" do
    source = <<~RUBY
      note = "brew.created"
    RUBY

    assert_empty Activity::EventContractCoverage.actions_in(source)
  end

  test "focused coverage scanner recognizes a literal action in an activity assertion" do
    source = <<~RUBY
      assert_activity_event(action: "brew.created", workspace: workspace) do
        post brews_path
      end
    RUBY

    assert_equal [ "brew.created" ], Activity::EventContractCoverage.actions_in(source)
  end

  test "focused coverage scanner recognizes literal actions in an exact multi-event assertion" do
    source = <<~RUBY
      assert_activity_events(actions: [ "workspace.created", "household_invite.accepted" ], workspace: workspace, actor: user) do
        post accept_household_invite_path(token)
      end
    RUBY

    assert_equal %w[household_invite.accepted workspace.created], Activity::EventContractCoverage.actions_in(source).sort
  end

  test "every registered action has focused mutation or operation test coverage" do
    covered_actions = Dir[Rails.root.join("test/{controllers,services,jobs,migrations}/**/*_test.rb")].sort.filter_map do |path|
      next if path.end_with?("event_contract_test.rb")
      Activity::EventContractCoverage.actions_in(File.read(path))
    end.flatten.uniq

    Activity::EventContract.actions.each do |action|
      assert_includes covered_actions, action, "add a focused assertion for #{action}"
    end
  end
end
