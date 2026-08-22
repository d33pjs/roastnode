require "test_helper"

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

  test "every registered action has focused mutation or operation test coverage" do
    test_source = Dir[Rails.root.join("test/{controllers,services,jobs}/**/*_test.rb")].sort.filter_map do |path|
      next if path.end_with?("event_contract_test.rb")
      File.read(path)
    end.join("\n")

    Activity::EventContract.actions.each do |action|
      assert_includes test_source, %("#{action}"), "add a focused assertion for #{action}"
    end
  end
end
