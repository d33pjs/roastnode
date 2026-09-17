require "test_helper"

class BrewGrinderReminderTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:household)
    @bean = beans(:second_open_household)
    @bean.update!(grind_state: "whole_bean")
    @grinder = equipment(:household_grinder)
  end

  test "uses the latest setting regardless of rating and ignores later blanks" do
    brew(setting: "1/2,75", rating: 5, occurred_at: 3.days.ago)
    latest = brew(setting: "1/1,25", rating: nil, occurred_at: 2.days.ago)
    brew(setting: " \t\n\v\f\r", rating: 5, occurred_at: 1.day.ago)

    assert_equal latest, history.reference.brew
    assert_equal "1/1,25", history.reference.grind_setting
    assert_equal 2, history.brew_count
  end

  test "finds the first unrated brew" do
    first = brew(setting: "first", rating: nil)
    assert_equal first, history.reference.brew
  end

  test "inherits settings on a new duplicated bag and prefers its own history thereafter" do
    source = brew(setting: "source", occurred_at: 2.days.ago)
    duplicate = @bean.duplicate_for_new_bag!
    inherited = history(duplicate)
    assert inherited.inherited
    assert_equal source, inherited.reference.brew
    own = brew(bean: duplicate, setting: "own", occurred_at: 3.days.ago)
    assert_not history(duplicate).inherited
    assert_equal own, history(duplicate).reference.brew
    assert_equal 2, history(duplicate).bag_count
  end

  test "keeps histories separate by grinder and method" do
    other_grinder = @workspace.equipment.create!(name: "Other grinder", kind: "grinder")
    first = brew(setting: "espresso", occurred_at: 2.days.ago)
    second = brew(grinder: other_grinder, setting: "other grinder")
    @workspace.brews.create!(user: users(:one), bean: @bean, grinder: @grinder,
      brewer: equipment(:household_brewer), method: "quick_drip", machine_cups: 4,
      bean_weight_grams: 1, occurred_at: Time.current, grind_setting: "filter")

    assert_equal first, history.reference.brew
    assert_equal second, history(@bean, other_grinder).reference.brew
    assert_equal "filter", result(method: "quick_drip").histories_for(@bean)[@grinder.id.to_s].reference.grind_setting
  end

  test "never borrows history from another grind state or an unrelated bag" do
    brew(setting: "whole")
    duplicate = @bean.duplicate_for_new_bag!
    duplicate.update!(grind_state: "pre_ground")
    assert_empty result(beans: [ duplicate ]).histories_for(duplicate)
    assert_empty result(beans: [ beans(:archived_household) ]).histories_for(beans(:archived_household))
  end

  test "excludes foreign workspace bags even if supplied to the service" do
    foreign = beans(:other_workspace_open)
    brew(workspace: workspaces(:other_household), bean: foreign,
      grinder: equipment(:other_workspace_grinder), setting: "secret")
    reminder = result(beans: [ @bean, foreign ])
    assert_empty reminder.histories_for(foreign)
    assert_empty reminder.histories_for(@bean)
  end

  test "does not offer settings from missing or deleted grinders" do
    brew(grinder: nil, setting: "unknown")
    assert_empty result.histories_for(@bean)
    disposable = @workspace.equipment.create!(name: "Gone", kind: "grinder")
    brew(grinder: disposable, setting: "deleted")
    disposable.destroy_with_history!
    assert_empty result.histories_for(@bean)
  end

  test "keeps references for archived grinders when that grinder is selected" do
    @grinder.update!(archived_at: 1.day.ago)
    saved = brew(setting: "archived")
    assert_equal saved, history.reference.brew
  end

  test "breaks occurrence ties by creation time then id" do
    occurred_at = 3.days.ago.change(usec: 0)
    older = brew(setting: "older", occurred_at:)
    newer = brew(setting: "newer", occurred_at:)
    older.update_columns(created_at: 2.hours.ago)
    newer.update_columns(created_at: 1.hour.ago)
    assert_equal newer, history.reference.brew
    same_creation = Time.current.change(usec: 0)
    older.update_columns(created_at: same_creation)
    newer.update_columns(created_at: same_creation)
    assert_equal newer, history.reference.brew
  end

  test "counts top three normalized settings across linked bags and keeps latest outside the top three" do
    duplicate = @bean.duplicate_for_new_bag!
    4.times { |i| brew(bean: i.even? ? @bean : duplicate, setting: i.even? ? " Dial A " : "dial a", occurred_at: 4.days.ago) }
    3.times { brew(setting: "B", occurred_at: 3.days.ago) }
    2.times { brew(setting: "C", occurred_at: 2.days.ago) }
    latest = brew(setting: "  Latest  ", occurred_at: 1.day.ago)
    found = history
    assert_equal [ 4, 3, 2 ], found.settings.map { |item| item[:count] }
    assert_equal [ "dial a", "b", "c" ], found.settings.map { |item| item[:setting].strip.downcase }
    assert_equal 10, found.brew_count
    assert_equal 2, found.bag_count
    assert_equal latest, found.reference.brew
    assert_equal "  Latest  ", found.reference.grind_setting
    assert_equal [ @grinder.id.to_s, "latest" ].to_json, found.reference.comparison_key
  end

  test "does not guess equivalence between decimal setting notations" do
    brew(setting: "1/1,25")
    brew(setting: "1/1.25")
    assert_equal 2, history.settings.size
    assert_equal [ 1, 1 ], history.settings.map { |row| row[:count] }
  end

  test "filters malformed cross workspace grinder and bean references" do
    saved = brew(setting: "foreign grinder")
    saved.update_columns(grinder_id: equipment(:other_workspace_grinder).id)
    assert_empty result.histories_for(@bean)
    saved.update_columns(grinder_id: @grinder.id, bean_id: beans(:other_workspace_open).id)
    assert_empty result.histories_for(@bean)
  end

  test "breaks equal setting frequencies by latest use" do
    brew(setting: "A", occurred_at: 3.days.ago)
    brew(setting: "B", occurred_at: 2.days.ago)
    brew(setting: "C", occurred_at: 1.day.ago)
    brew(setting: "D", occurred_at: Time.current)
    assert_equal [ "D", "C", "B" ], history.settings.map { |item| item[:setting] }
  end

  test "reflects corrected and deleted brews without cached history" do
    older = brew(setting: "old", occurred_at: 2.days.ago)
    latest = brew(setting: "new", occurred_at: 1.day.ago)
    latest.update!(grind_setting: "corrected")
    assert_equal "corrected", history.reference.grind_setting
    latest.destroy_with_inventory_reversal!
    assert_equal older, history.reference.brew
    assert_equal 1, history.brew_count
  end

  test "keeps operator last used before newer workspace history and excludes other methods" do
    brews(:morning_espresso).update!(user: users(:two), occurred_at: 4.days.ago)
    own = brew(user: users(:one), setting: "mine", occurred_at: 3.days.ago)
    brew(user: users(:two), bean: beans(:open_household), setting: "theirs", occurred_at: 1.day.ago)
    reminder = result
    assert_equal own, reminder.previous.brew
    assert_equal @bean.id, reminder.last_bean_id
  end

  test "falls back to workspace last brew and retains its closed bean" do
    brews(:morning_espresso).update!(user: users(:one), occurred_at: 4.days.ago)
    latest = brew(user: users(:one), setting: nil)
    @bean.update!(remaining_grams: 0)
    reminder = result(user: users(:two), beans: [ beans(:open_household) ])
    assert_equal latest, reminder.previous.brew
    assert_equal @bean, reminder.last_bean
  end

  test "query and materialized result counts stay bounded as history grows" do
    12.times { |i| brew(setting: "setting #{i}", occurred_at: i.hours.ago) }
    count = 0
    loaded_brews = 0
    callback = ->(*args) { count += 1 unless args.last[:cached] || args.last[:name] == "SCHEMA" }
    instantiations = ->(*args) { loaded_brews += args.last[:record_count] if args.last[:class_name] == "Brew" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      ActiveSupport::Notifications.subscribed(instantiations, "instantiation.active_record") do
        found = history
        assert_equal 12, found.brew_count
        assert_equal 3, found.settings.size
      end
    end
    assert_operator count, :<=, 15
    assert_operator loaded_brews, :<=, 3
  end

  private
    def result(beans: [ @bean ], user: users(:one), method: "espresso")
      BrewGrinderReminder.new(workspace: @workspace, user:, method:, beans:).call
    end

    def history(bean = @bean, grinder = @grinder)
      result(beans: [ bean ]).histories_for(bean)[grinder.id.to_s]
    end

    def brew(bean: @bean, grinder: @grinder, workspace: @workspace, user: users(:one), setting:, rating: nil, occurred_at: Time.current)
      workspace.brews.create!(user:, bean:, grinder:, machine: workspace.equipment.machine.first,
        method: "espresso", occurred_at:, bean_weight_grams: 1, grind_setting: setting, rating:)
    end
end
