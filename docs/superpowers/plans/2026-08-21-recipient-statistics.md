# Recipient-Aware Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent “Logged by” and “Served to” filters to workspace Statistics so every Brew-derived metric follows the selected people and date scope while current Bean catalog facts remain unfiltered.

**Architecture:** Extend the existing `WorkspaceStatistics` query boundary with two prevalidated filter values: a logger User ID and a recipient token. Add a small `WorkspaceStatisticsPeople` service that derives safe current-and-historical option sets from the active workspace and rejects unknown or foreign-workspace parameters before they reach the aggregate query. Keep the existing statistics response shape, preserve people parameters across timeframe navigation, and render explicit no-data states from the existing nil/empty aggregate values.

**Tech Stack:** Rails 8, Active Record, ERB, I18n YAML, Minitest service/integration tests, Tailwind CSS.

## Global Constraints

- Execute this plan only after the Brew recipient plan has added `Brew.recipient_kind`, optional `Brew.recipient_user_id`, the `recipient_user` association, and legacy-data migration.
- Use these exact query parameters: `logger_id=<user id>` and `recipient=self|guests|user:<user id>`.
- “Logged by” and “Served to” are independent and combine with the inclusive start/end date range.
- A specific recipient User matches both that User's Self Brews and Brews explicitly served to that User as a household member.
- The aggregate Guests option includes all Guest Brews and never exposes individual guest names as filter options.
- Logger and recipient User options may include current members plus historical Users represented by this workspace's Brew history. Labels use `User#display_label`, never email.
- Every Brew query starts from `workspace.brews`; never resolve an arbitrary User globally and then trust that ID.
- Unknown, malformed, or foreign-workspace people parameters raise `ActiveRecord::RecordNotFound` and return the application's normal 404 response.
- Quick timeframe links preserve people; clearing people preserves time; Reset all clears both and restores the normal seven-day default.
- Apply date and people filters to all Brew-derived totals, costs, leaders, rates, distributions, and series.
- Keep open Bean count, known Bean spend, and Bean roaster/origin/process breakdowns current and unfiltered; retain visible explanatory copy.
- External Coffees remain outside `WorkspaceStatistics`.
- Protect unrelated user changes, remain on `main`, and commit after each completed task.

---

## Dependency And File Structure

**Depends on:** `docs/superpowers/plans/2026-08-21-brew-recipient-hero.md`.

- Create: `app/services/workspace_statistics_people.rb` — derive safe logger/recipient option Users and validate filter tokens.
- Create: `test/services/workspace_statistics_people_test.rb` — current, historical, guest, malformed, and cross-workspace coverage.
- Modify: `app/services/workspace_statistics.rb` — apply the validated logger and recipient scope to every Brew-derived aggregate.
- Modify: `test/services/workspace_statistics_test.rb` — independent and combined aggregate filter coverage.
- Modify: `app/controllers/statistics_controller.rb` — resolve people parameters, expose options, and preserve navigation query state.
- Modify: `app/views/statistics/index.html.erb` — add responsive people selectors, reset behavior, and explicit leader empty states.
- Modify: `test/controllers/statistics_controller_test.rb` — option privacy, selected state, parameter preservation, rejection, and empty-state coverage.
- Modify: `config/locales/en.yml` — filter, option, reset, and no-data copy.
- Modify: `docs/statistics.md` — document recipient-aware scope semantics.
- Modify: `docs/coffee-core.md` — cross-reference recipient meanings in analytics.
- Modify: `docs/status.md` — record the delivered capability.

---

### Task 1: Apply Logger And Recipient Filters To Every Brew Aggregate

**Files:**

- Modify: `test/services/workspace_statistics_test.rb`
- Modify: `app/services/workspace_statistics.rb`

**Interfaces:**

- Consumes: `WorkspaceStatistics.new(workspace:, start_date: nil, end_date: nil, logger_id: nil, recipient_filter: nil)`.
- Accepted `recipient_filter` values after controller validation: `nil`, `"self"`, `"guests"`, or `"user:<id>"`.
- Produces: the existing `call` hash shape; only Brew-backed values are narrowed.

- [ ] **Step 1: Add a focused Brew factory helper to the service test**

Add this private helper at the bottom of `WorkspaceStatisticsTest`. It keeps recipient scenarios readable and uses workspace-owned records:

~~~ruby
private
  def create_statistics_brew!(
    workspace: workspaces(:household),
    user: users(:one),
    recipient_kind: "self",
    recipient_user: nil,
    occurred_at: Time.zone.local(2026, 5, 26, 10, 0, 0),
    bean: beans(:second_open_household),
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    bean_weight_grams: 20,
    taste_balance: "bitter",
    channeling: true
  )
    workspace.brews.create!(
      user:,
      recipient_kind:,
      recipient_user:,
      bean:,
      grinder:,
      machine:,
      occurred_at:,
      bean_weight_grams:,
      ground_weight_grams: bean_weight_grams,
      dose_grams: bean_weight_grams,
      beverage_grams: 40,
      total_time_seconds: 30,
      taste_balance:,
      channeling:,
      rating: 4
    )
  end
~~~

- [ ] **Step 2: Write failing tests for independent logger and recipient filters**

Add these tests before the private section:

~~~ruby
test "filters every brew aggregate by logger while keeping bean catalog totals current" do
  travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
    workspace = workspaces(:household)
    owner = users(:one)
    member = users(:two)
    brews(:morning_espresso).update!(
      user: owner,
      recipient_kind: "self",
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      taste_balance: "neutral",
      channeling: false
    )
    create_statistics_brew!(
      workspace:,
      user: member,
      recipient_kind: "self",
      bean_weight_grams: 20,
      taste_balance: "bitter",
      channeling: true
    )

    statistics = WorkspaceStatistics.new(
      workspace:,
      logger_id: member.id
    ).call

    assert_equal 1, statistics[:totals][:total_brews]
    assert_equal 20.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_nil statistics[:totals][:average_known_brew_cost_cents]
    assert_equal 0, statistics[:totals][:priced_brew_count]
    assert_equal({ "bitter" => 1 }, statistics[:distributions][:taste_balance])
    assert_equal({ "espresso" => 1 }, statistics[:distributions][:method])
    assert_equal 100, statistics[:rates][:channeling_percent]
    assert_equal({ name: "Niche Zero", count: 1 }, statistics[:leaders][:grinder])
    assert_equal 1, statistics[:series][:brews_by_day].sum { |point| point[:count] }

    assert_equal 2, statistics[:totals][:open_beans]
    assert_equal 1290, statistics[:totals][:known_spend_cents]
    assert_includes statistics[:breakdowns][:roasters], { label: "North Star", count: 1 }
  end
end

test "filters self and guest recipients independently" do
  travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
    workspace = workspaces(:household)
    brews(:morning_espresso).update!(
      recipient_kind: "self",
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
    )
    create_statistics_brew!(
      workspace:,
      user: users(:two),
      recipient_kind: "guest",
      bean_weight_grams: 20
    )

    self_statistics = WorkspaceStatistics.new(
      workspace:,
      recipient_filter: "self"
    ).call
    guest_statistics = WorkspaceStatistics.new(
      workspace:,
      recipient_filter: "guests"
    ).call

    assert_equal 1, self_statistics[:totals][:total_brews]
    assert_equal 18.to_d, self_statistics[:totals][:total_bean_weight_grams]
    assert_equal 1, guest_statistics[:totals][:total_brews]
    assert_equal 20.to_d, guest_statistics[:totals][:total_bean_weight_grams]
  end
end
~~~

- [ ] **Step 3: Write failing tests for a named User and the complete combined scope**

Add:

~~~ruby
test "specific recipient includes their self brews and household member servings" do
  travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
    workspace = workspaces(:household)
    petra = users(:two)
    brews(:morning_espresso).update!(
      user: users(:one),
      recipient_kind: "household_member",
      recipient_user: petra,
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
    )
    create_statistics_brew!(
      workspace:,
      user: petra,
      recipient_kind: "self",
      bean_weight_grams: 20
    )
    create_statistics_brew!(
      workspace:,
      user: users(:one),
      recipient_kind: "guest",
      occurred_at: Time.zone.local(2026, 5, 26, 11, 0, 0),
      bean_weight_grams: 22
    )

    statistics = WorkspaceStatistics.new(
      workspace:,
      recipient_filter: "user:#{petra.id}"
    ).call

    assert_equal 2, statistics[:totals][:total_brews]
    assert_equal 38.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 2, statistics[:series][:brews_by_day].sum { |point| point[:count] }
  end
end

test "combines logger recipient and inclusive date filters across all brew metrics" do
  workspace = workspaces(:household)
  logger = users(:one)
  recipient = users(:two)
  included = brews(:morning_espresso)
  included.update!(
    user: logger,
    recipient_kind: "household_member",
    recipient_user: recipient,
    occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
    taste_balance: "neutral",
    channeling: false
  )
  create_statistics_brew!(
    workspace:,
    user: users(:two),
    recipient_kind: "self",
    occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0),
    bean_weight_grams: 20
  )
  create_statistics_brew!(
    workspace:,
    user: logger,
    recipient_kind: "household_member",
    recipient_user: recipient,
    occurred_at: Time.zone.local(2026, 5, 20, 9, 0, 0),
    bean_weight_grams: 22
  )

  statistics = WorkspaceStatistics.new(
    workspace:,
    start_date: Date.new(2026, 5, 26),
    end_date: Date.new(2026, 5, 26),
    logger_id: logger.id,
    recipient_filter: "user:#{recipient.id}"
  ).call

  assert_equal 1, statistics[:totals][:total_brews]
  assert_equal 18.to_d, statistics[:totals][:total_bean_weight_grams]
  assert_equal({ "neutral" => 1 }, statistics[:distributions][:taste_balance])
  assert_equal({ "normal" => 1 }, statistics[:distributions][:retention_marker])
  assert_equal({ "espresso" => 1 }, statistics[:distributions][:method])
  assert_equal 0, statistics[:rates][:channeling_percent]
  assert_equal({ name: "Niche Zero", count: 1 }, statistics[:leaders][:grinder])
  assert_equal({ name: "Bianca", count: 1 }, statistics[:leaders][:machine])
  assert_equal [ 1 ], statistics[:series][:brews_by_day].map { |point| point[:count] }
  assert_equal [ 18.to_d ], statistics[:series][:consumption_by_day].map { |point| point[:grams] }
end
~~~

- [ ] **Step 4: Run the service tests and verify the new constructor arguments fail**

Run:

~~~bash
bin/rails test test/services/workspace_statistics_test.rb
~~~

Expected: ERROR with unknown keywords `logger_id` and `recipient_filter`.

- [ ] **Step 5: Extend the initializer and central Brew relation**

Update `WorkspaceStatistics`:

~~~ruby
def initialize(
  workspace:,
  start_date: nil,
  end_date: nil,
  logger_id: nil,
  recipient_filter: nil
)
  @workspace = workspace
  @start_date = (start_date || self.class.default_start_date).to_date
  @end_date = (end_date || self.class.default_end_date).to_date
  @start_date, @end_date = @end_date, @start_date if @start_date > @end_date
  @logger_id = logger_id
  @recipient_filter = recipient_filter
end

private
  attr_reader :workspace, :start_date, :end_date, :logger_id, :recipient_filter

  def brews
    @brews ||= filtered_brew_scope
      .includes(:bean, :grinder, :machine, :brewer)
      .to_a
  end

  def filtered_brew_scope
    scope = workspace.brews.where(
      occurred_at: start_date.beginning_of_day..end_date.end_of_day
    )
    scope = scope.where(user_id: logger_id) if logger_id.present?
    apply_recipient_filter(scope)
  end

  def apply_recipient_filter(scope)
    case recipient_filter
    when nil
      scope
    when "self"
      scope.where(recipient_kind: "self")
    when "guests"
      scope.where(recipient_kind: "guest")
    when /\Auser:(\d+)\z/
      recipient_user_id = Regexp.last_match(1).to_i
      scope.where(
        <<~SQL.squish,
          (brews.recipient_kind = :self AND brews.user_id = :user_id)
          OR
          (brews.recipient_kind = :household_member AND brews.recipient_user_id = :user_id)
        SQL
        user_id: recipient_user_id
      )
    else
      raise ArgumentError, "unsupported recipient filter"
    end
  end
~~~

Do not add filtering to `beans`; that separation is the approved catalog boundary.

- [ ] **Step 6: Run the focused aggregate suite**

Run:

~~~bash
bin/rails test test/services/workspace_statistics_test.rb
~~~

Expected: PASS, including existing date and Quick Drip tests.

- [ ] **Step 7: Commit the aggregate query**

~~~bash
git add app/services/workspace_statistics.rb test/services/workspace_statistics_test.rb
git commit -m "Filter workspace statistics by logger and recipient"
~~~

---

### Task 2: Derive Workspace-Safe Current And Historical People Options

**Files:**

- Create: `test/services/workspace_statistics_people_test.rb`
- Create: `app/services/workspace_statistics_people.rb`

**Interfaces:**

- `WorkspaceStatisticsPeople.new(workspace:)`.
- `logger_users -> Array<User>`.
- `recipient_users -> Array<User>`.
- `resolve_logger_id(value) -> Integer | nil`.
- `resolve_recipient_filter(value) -> "self" | "guests" | "user:<id>" | nil`.
- Resolution raises `ActiveRecord::RecordNotFound` for malformed, unknown, or out-of-scope values.

- [ ] **Step 1: Write failing option and privacy tests**

Create `test/services/workspace_statistics_people_test.rb`:

~~~ruby
require "test_helper"

class WorkspaceStatisticsPeopleTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:household)
    users(:one).update!(display_name: "Jens")
    users(:two).update!(display_name: "Petra")
  end

  test "logger users include current members and historical workspace loggers once" do
    historical = User.create!(
      email_address: "historical-logger@example.com",
      password: "password",
      display_name: "Former logger"
    )
    membership = @workspace.memberships.create!(user: historical, role: "member")
    brews(:morning_espresso).update!(user: historical)
    membership.destroy!

    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_equal(
      [ "Former logger", "Jens", "Petra" ],
      people.logger_users.map(&:display_label)
    )
  end

  test "recipient users include current members and historical self or member recipients" do
    historical = User.create!(
      email_address: "historical-recipient@example.com",
      password: "password",
      display_name: "Former recipient"
    )
    membership = @workspace.memberships.create!(user: historical, role: "member")
    brews(:morning_espresso).update!(
      recipient_kind: "household_member",
      recipient_user: historical
    )
    membership.destroy!

    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_equal(
      [ "Former recipient", "Jens", "Petra" ],
      people.recipient_users.map(&:display_label)
    )
  end

  test "guest names never become recipient options" do
    brews(:morning_espresso).update!(
      recipient_kind: "guest",
      recipient_name: "Secret Guest"
    )

    labels = WorkspaceStatisticsPeople.new(workspace: @workspace)
      .recipient_users
      .map(&:display_label)

    refute_includes labels, "Secret Guest"
  end

  test "resolves blank built in and workspace user values" do
    people = WorkspaceStatisticsPeople.new(workspace: @workspace)

    assert_nil people.resolve_logger_id(nil)
    assert_nil people.resolve_recipient_filter("")
    assert_equal users(:one).id, people.resolve_logger_id(users(:one).id.to_s)
    assert_equal "self", people.resolve_recipient_filter("self")
    assert_equal "guests", people.resolve_recipient_filter("guests")
    assert_equal(
      "user:#{users(:two).id}",
      people.resolve_recipient_filter("user:#{users(:two).id}")
    )
  end
end
~~~

- [ ] **Step 2: Write failing authorization tests**

Append:

~~~ruby
test "rejects malformed unknown and foreign logger ids" do
  people = WorkspaceStatisticsPeople.new(workspace: @workspace)
  foreign_id = users(:two).id
  brews(:morning_espresso).update!(user: users(:one))
  memberships(:member).destroy!

  [ "abc", "999999", foreign_id.to_s, [ users(:one).id.to_s ], { "id" => users(:one).id.to_s } ].each do |value|
    assert_raises(ActiveRecord::RecordNotFound) do
      people.resolve_logger_id(value)
    end
  end
end

test "rejects malformed unknown and foreign recipient values" do
  people = WorkspaceStatisticsPeople.new(workspace: @workspace)
  foreign_id = users(:two).id
  memberships(:member).destroy!

  [ "guest", "user:abc", "user:999999", "user:#{foreign_id}", [ "self" ], { "kind" => "self" } ].each do |value|
    assert_raises(ActiveRecord::RecordNotFound) do
      people.resolve_recipient_filter(value)
    end
  end
end
~~~

The foreign-ID setup deliberately removes the current membership and leaves no Brew history for User two in `household`; their Brew in `other_household` must not authorize the ID.

- [ ] **Step 3: Run the new test and verify the missing service fails**

Run:

~~~bash
bin/rails test test/services/workspace_statistics_people_test.rb
~~~

Expected: ERROR because `WorkspaceStatisticsPeople` is undefined.

- [ ] **Step 4: Implement the workspace-bounded people resolver**

Create `app/services/workspace_statistics_people.rb`:

~~~ruby
class WorkspaceStatisticsPeople
  RECIPIENT_SELF = "self"
  RECIPIENT_GUESTS = "guests"
  USER_RECIPIENT_PATTERN = /\Auser:(\d+)\z/

  def initialize(workspace:)
    @workspace = workspace
  end

  def logger_users
    @logger_users ||= users_for(
      current_user_ids | workspace.brews.distinct.pluck(:user_id)
    )
  end

  def recipient_users
    @recipient_users ||= users_for(
      current_user_ids |
        workspace.brews.where(recipient_kind: "self").distinct.pluck(:user_id) |
        workspace.brews
          .where(recipient_kind: "household_member")
          .where.not(recipient_user_id: nil)
          .distinct
          .pluck(:recipient_user_id)
    )
  end

  def resolve_logger_id(value)
    return nil if value.blank?

    id = Integer(value, 10)
    return id if logger_users.any? { |user| user.id == id }

    raise ActiveRecord::RecordNotFound
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordNotFound
  end

  def resolve_recipient_filter(value)
    return nil if value.blank?
    raise ActiveRecord::RecordNotFound unless value.is_a?(String)
    return value if [ RECIPIENT_SELF, RECIPIENT_GUESTS ].include?(value)

    match = USER_RECIPIENT_PATTERN.match(value)
    raise ActiveRecord::RecordNotFound unless match

    id = match[1].to_i
    raise ActiveRecord::RecordNotFound unless recipient_users.any? { |user| user.id == id }

    "user:#{id}"
  end

  private
    attr_reader :workspace

    def current_user_ids
      @current_user_ids ||= workspace.users.distinct.pluck(:id)
    end

    def users_for(ids)
      User.where(id: ids.compact.uniq).to_a.sort_by do |user|
        [ user.display_label.downcase, user.id ]
      end
    end
end
~~~

This service intentionally returns User records for rendering, but it only queries IDs derived from active membership or active-workspace Brew history.

- [ ] **Step 5: Run focused and neighboring service suites**

Run:

~~~bash
bin/rails test test/services/workspace_statistics_people_test.rb test/services/workspace_statistics_test.rb
~~~

Expected: PASS.

- [ ] **Step 6: Commit the people resolver**

~~~bash
git add app/services/workspace_statistics_people.rb test/services/workspace_statistics_people_test.rb
git commit -m "Resolve safe statistics people filters"
~~~

---

### Task 3: Wire People Filters Into Statistics Navigation And Presentation

**Files:**

- Modify: `test/controllers/statistics_controller_test.rb`
- Modify: `app/controllers/statistics_controller.rb`
- Modify: `app/views/statistics/index.html.erb`
- Modify: `config/locales/en.yml`

**Interfaces:**

- GET `/statistics?logger_id=<id>&recipient=<token>&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`.
- View assigns: `@statistics_logger_users`, `@statistics_recipient_users`, `@statistics_logger_id`, and `@statistics_recipient_filter`.
- Stable test hooks: `statistics-logger-filter`, `statistics-recipient-filter`, `statistics-clear-people`, `statistics-reset-all`, and `statistics-no-brew-data`.

- [ ] **Step 1: Write failing integration coverage for labels, selections, and aggregate results**

Add to `StatisticsControllerTest`:

~~~ruby
test "statistics offers private-safe logger and recipient filters and keeps selections" do
  users(:one).update!(display_name: "Jens")
  users(:two).update!(display_name: "Petra")
  brews(:morning_espresso).update!(
    user: users(:one),
    recipient_kind: "household_member",
    recipient_user: users(:two)
  )
  sign_in_as(users(:one))

  get statistics_path,
    params: {
      logger_id: users(:one).id,
      recipient: "user:#{users(:two).id}"
    }

  assert_response :success
  assert_select "select[data-testid=statistics-logger-filter]" do
    assert_select "option", text: I18n.t("statistics.index.all_loggers")
    assert_select "option[selected][value=?]", users(:one).id.to_s, text: "Jens"
    assert_select "option", text: "Petra"
  end
  assert_select "select[data-testid=statistics-recipient-filter]" do
    assert_select "option", text: I18n.t("statistics.index.all_recipients")
    assert_select "option[value=self]", text: I18n.t("statistics.index.self_served")
    assert_select "option[value=guests]", text: I18n.t("statistics.index.guests")
    assert_select "option[selected][value=?]", "user:#{users(:two).id}", text: "Petra"
  end
  assert_select "body", text: /one@example\.com/, count: 0
  assert_select "[data-testid=total-brews]", "1"
end

test "statistics offers former workspace people by display label without email" do
  historical = User.create!(
    email_address: "former-person@example.com",
    password: "password",
    display_name: "Former person"
  )
  membership = workspaces(:household).memberships.create!(
    user: historical,
    role: "member"
  )
  workspaces(:household).brews.create!(
    user: historical,
    recipient_kind: "self",
    bean: beans(:second_open_household),
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    bean_weight_grams: 20,
    ground_weight_grams: 20,
    dose_grams: 20,
    beverage_grams: 40
  )
  membership.destroy!
  sign_in_as(users(:one))

  get statistics_path

  assert_response :success
  assert_select "select[data-testid=statistics-logger-filter] option",
    text: "Former person"
  assert_select "select[data-testid=statistics-recipient-filter] option",
    text: "Former person"
  assert_select "body", text: /former-person@example\.com/, count: 0
end
~~~

- [ ] **Step 2: Write failing integration coverage for combined filters and rejection**

Add:

~~~ruby
test "statistics combines logger recipient and date filters" do
  workspace = workspaces(:household)
  petra = users(:two)
  brews(:morning_espresso).update!(
    user: users(:one),
    recipient_kind: "household_member",
    recipient_user: petra,
    occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
  )
  workspace.brews.create!(
    user: petra,
    recipient_kind: "self",
    bean: beans(:second_open_household),
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0),
    bean_weight_grams: 20,
    ground_weight_grams: 20,
    dose_grams: 20,
    beverage_grams: 40
  )
  sign_in_as(users(:one))

  get statistics_path,
    params: {
      start_date: "2026-05-26",
      end_date: "2026-05-26",
      logger_id: users(:one).id,
      recipient: "user:#{petra.id}"
    }

  assert_response :success
  assert_select "[data-testid=total-brews]", "1"
  assert_select "[data-testid=total-ground]", "18g"
end

test "statistics rejects people identifiers outside the active workspace" do
  memberships(:member).destroy!
  sign_in_as(users(:one))

  get statistics_path, params: { logger_id: users(:two).id }
  assert_response :not_found

  get statistics_path, params: { recipient: "user:#{users(:two).id}" }
  assert_response :not_found
end

test "statistics rejects non scalar people parameters" do
  sign_in_as(users(:one))

  get statistics_path, params: { logger_id: [ users(:one).id ] }
  assert_response :not_found

  get statistics_path, params: { recipient: [ "self" ] }
  assert_response :not_found
end
~~~

- [ ] **Step 3: Write failing navigation-preservation and empty-state tests**

Add:

~~~ruby
test "timeframe and reset links preserve or clear people filters deliberately" do
  users(:one).update!(display_name: "Jens")
  sign_in_as(users(:one))

  get statistics_path,
    params: {
      timeframe: "last_30_days",
      logger_id: users(:one).id,
      recipient: "self"
    }

  assert_response :success
  assert_select "a[data-testid=statistics-timeframe-last_7_days][href=?]",
    statistics_path(
      timeframe: "last_7_days",
      logger_id: users(:one).id,
      recipient: "self"
    )
  assert_select "a[href=?]", statistics_path(
    logger_id: users(:one).id,
    recipient: "self"
  ), text: I18n.t("statistics.index.reset_timerange")
  assert_select "a[data-testid=statistics-clear-people][href=?]",
    statistics_path(timeframe: "last_30_days")
  assert_select "a[data-testid=statistics-reset-all][href=?]",
    statistics_path
end

test "empty people result shows no brew data without hiding current bean catalog" do
  sign_in_as(users(:one))

  get statistics_path,
    params: {
      timeframe: "last_7_days",
      logger_id: users(:two).id,
      recipient: "guests"
    }

  assert_response :success
  assert_select "[data-testid=total-brews]", "0"
  assert_select "[data-testid=statistics-no-brew-data]",
    I18n.t("statistics.index.no_filtered_brew_data")
  assert_select "[data-testid=average-brew-cost]",
    I18n.t("statistics.index.no_average_brew_cost")
  assert_select "[data-testid=open-beans]", "2"
  assert_select "[data-testid=statistics-current-catalog-note]",
    I18n.t("statistics.index.current_inventory_note")
  assert_select "section[data-testid=statistics-equipment] p",
    text: I18n.t("statistics.index.no_data"),
    minimum: 1
end
~~~

- [ ] **Step 4: Run the controller suite and verify the filters are missing**

Run:

~~~bash
bin/rails test test/controllers/statistics_controller_test.rb
~~~

Expected: FAIL because the selects, resolver, query parameters, and new empty-state hooks do not exist.

- [ ] **Step 5: Resolve and pass the people filters from the controller**

Update `StatisticsController#index` before building `WorkspaceStatistics`:

~~~ruby
def index
  @statistics_timeframe = statistics_timeframe
  @statistics_timeframe_options = TIMEFRAMES
  @statistics_start_date, @statistics_end_date = statistics_date_range

  people = WorkspaceStatisticsPeople.new(workspace: current_workspace)
  @statistics_logger_users = people.logger_users
  @statistics_recipient_users = people.recipient_users
  @statistics_logger_id = people.resolve_logger_id(params[:logger_id])
  @statistics_recipient_filter = people.resolve_recipient_filter(params[:recipient])

  @statistics = WorkspaceStatistics.new(
    workspace: current_workspace,
    start_date: @statistics_start_date,
    end_date: @statistics_end_date,
    logger_id: @statistics_logger_id,
    recipient_filter: @statistics_recipient_filter
  ).call
end
~~~

Add these private helpers:

~~~ruby
def statistics_people_params
  {
    logger_id: @statistics_logger_id,
    recipient: @statistics_recipient_filter
  }.compact
end
helper_method :statistics_people_params

def statistics_time_params
  if @statistics_timeframe.present?
    { timeframe: @statistics_timeframe }
  else
    {
      start_date: @statistics_start_date.iso8601,
      end_date: @statistics_end_date.iso8601
    }
  end
end
helper_method :statistics_time_params
~~~

Do not authorize options through raw `User.find`; all validation stays in `WorkspaceStatisticsPeople`.

- [ ] **Step 6: Add the localized controls and copy**

Under `statistics.index` in `config/locales/en.yml`, add:

~~~yaml
      all_loggers: "All loggers"
      all_recipients: "All recipients"
      clear_people: "Clear people"
      guests: "Guests"
      logged_by: "Logged by"
      no_filtered_brew_data: "No brews match these filters."
      reset_all: "Reset all"
      self_served: "Self-served"
      served_to: "Served to"
~~~

Also replace the two existing messages so they describe the complete filter boundary:

~~~yaml
      current_inventory_note: "Current inventory, not affected by date or people filters."
      no_average_brew_cost: "No brew cost data matches the selected filters."
~~~

Keep `no_data` as the generic leader/chart empty label.

- [ ] **Step 7: Add responsive people selectors and parameter-aware links**

In the GET form in `app/views/statistics/index.html.erb`, add the two selectors before the submit button:

~~~erb
<div>
  <%= form.label :logger_id, t(".logged_by"), class: "block text-sm font-semibold uppercase text-stone-600" %>
  <%= form.select :logger_id,
    options_for_select(
      [[t(".all_loggers"), ""]] +
        @statistics_logger_users.map { |user| [user.display_label, user.id] },
      @statistics_logger_id
    ),
    {},
    data: { testid: "statistics-logger-filter" },
    class: "mt-1 min-w-44 rounded-lg border border-stone-300 bg-white px-3 py-2 text-base text-stone-950 shadow-sm" %>
</div>
<div>
  <%= form.label :recipient, t(".served_to"), class: "block text-sm font-semibold uppercase text-stone-600" %>
  <% recipient_options = [
    [t(".all_recipients"), ""],
    [t(".self_served"), "self"],
    *@statistics_recipient_users.map { |user| [user.display_label, "user:#{user.id}"] },
    [t(".guests"), "guests"]
  ] %>
  <%= form.select :recipient,
    options_for_select(recipient_options, @statistics_recipient_filter),
    {},
    data: { testid: "statistics-recipient-filter" },
    class: "mt-1 min-w-44 rounded-lg border border-stone-300 bg-white px-3 py-2 text-base text-stone-950 shadow-sm" %>
</div>
~~~

Change the reset and quick-link targets:

~~~erb
<%= link_to t(".reset_timerange"),
  statistics_path(statistics_people_params),
  class: "rounded-lg border border-stone-300 bg-white px-4 py-2 font-semibold text-stone-950 shadow-sm" %>
<%= link_to t(".clear_people"),
  statistics_path(statistics_time_params),
  data: { testid: "statistics-clear-people" },
  class: "rounded-lg border border-stone-300 bg-white px-4 py-2 font-semibold text-stone-950 shadow-sm" %>
<%= link_to t(".reset_all"),
  statistics_path,
  data: { testid: "statistics-reset-all" },
  class: "rounded-lg border border-stone-300 bg-white px-4 py-2 font-semibold text-stone-950 shadow-sm" %>
~~~

For every timeframe link, prepend the timeframe and then merge the people parameters:

~~~erb
statistics_path({ timeframe: }.merge(statistics_people_params))
~~~

The form's date fields already submit their displayed values, so applying people filters with the form intentionally switches from a named shortcut to the equivalent manual inclusive range.

- [ ] **Step 8: Render explicit empty Brew states without changing catalog cards**

Immediately before the Brew metric-card grid, add:

~~~erb
<% if @statistics[:totals][:total_brews].zero? %>
  <p data-testid="statistics-no-brew-data" class="mt-6 rounded-lg border border-stone-200 bg-white px-4 py-3 text-sm font-semibold text-stone-700 shadow-sm">
    <%= t(".no_filtered_brew_data") %>
  </p>
<% end %>
~~~

Add `data-testid="statistics-equipment"` to the equipment section and replace the current fallback name/count pair with:

~~~erb
<% if leader.present? %>
  <p class="mt-2 text-2xl font-bold text-stone-950"><%= leader.fetch(:name) %></p>
  <p class="mt-1 text-sm text-stone-600"><%= t(".brew_count", count: leader.fetch(:count)) %></p>
<% else %>
  <p class="mt-2 text-base font-semibold text-stone-700"><%= t(".no_data") %></p>
<% end %>
~~~

Leave the existing average-cost nil state and chart partial empty states intact; they already avoid invented averages and distributions.

Inside the Bean breakdown card, add the same catalog-boundary note so roaster, origin, and process data cannot be mistaken for filtered results:

~~~erb
<p data-testid="statistics-current-catalog-note" class="mb-4 text-sm text-stone-600">
  <%= t(".current_inventory_note") %>
</p>
~~~

- [ ] **Step 9: Run controller and service tests**

Run:

~~~bash
bin/rails test test/controllers/statistics_controller_test.rb test/services/workspace_statistics_people_test.rb test/services/workspace_statistics_test.rb
~~~

Expected: PASS.

- [ ] **Step 10: Commit the controller and UI**

~~~bash
git add app/controllers/statistics_controller.rb app/views/statistics/index.html.erb config/locales/en.yml test/controllers/statistics_controller_test.rb
git commit -m "Add people filters to statistics"
~~~

---

### Task 4: Document, Regression-Test, And Visually Verify The Analytics Contract

**Files:**

- Modify: `docs/statistics.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/status.md`
- Test: statistics service and controller suites

- [ ] **Step 1: Update the durable product documentation**

In `docs/statistics.md`, document:

- `Logged by` filters the Brew logger independently of recipient.
- `Served to` supports Self-served, named current/historical Users, and aggregate Guests.
- A named User combines their Self Brews with household-member servings addressed to them.
- Guest names are private display data, not analytics identities.
- Date, logger, and recipient scopes affect every Brew-derived metric.
- Current Bean counts, spend, and roaster/origin/process breakdowns intentionally ignore all three filters.
- People tokens are validated against current membership or this workspace's Brew history.

In `docs/coffee-core.md`, add a short link from the recipient-kind section to the Statistics semantics. In `docs/status.md`, record the two independent filters and the current-catalog exception.

- [ ] **Step 2: Run the full relevant regression slice**

Run:

~~~bash
bin/rails test \
  test/models/brew_test.rb \
  test/services/workspace_statistics_people_test.rb \
  test/services/workspace_statistics_test.rb \
  test/controllers/statistics_controller_test.rb
~~~

Expected: PASS with no failures or errors.

- [ ] **Step 3: Run the complete Rails suite**

Run:

~~~bash
bin/rails test
~~~

Expected: PASS. If an unrelated pre-existing failure appears, record its exact test name and output before proceeding; do not weaken the new assertions.

- [ ] **Step 4: Start the required development server**

Follow the repository guide and run `bin/dev` inside the `roastnode-dev` tmux session. Confirm the process binds on host port 3001 and is reachable via the configured network DNS name.

- [ ] **Step 5: Perform responsive browser verification**

Check Statistics in light and dark themes at a narrow mobile viewport and a desktop viewport:

- people controls wrap without clipping;
- Current Users, a historical User, Self-served, and Guests show the expected safe labels;
- guest names and emails never appear;
- applying each filter updates totals, leaders, charts, distributions, rates, and average cost together;
- current Bean catalog cards do not change;
- quick timeframe links keep both people selections;
- Reset timerange keeps people selections;
- Clear people keeps the selected timeframe or manual dates;
- Reset all clears people and restores the normal seven-day defaults;
- an empty Brew result shows the explicit no-data banner and no fake equipment leader.

- [ ] **Step 6: Commit documentation**

~~~bash
git add docs/statistics.md docs/coffee-core.md docs/status.md
git commit -m "Document recipient-aware statistics"
~~~

- [ ] **Step 7: Verify the task commits and working tree**

Run:

~~~bash
git status --short
git log --oneline -4
~~~

Expected: no uncommitted task files, and the aggregate, resolver, UI, and documentation commits are present.
