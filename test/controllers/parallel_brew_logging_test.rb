require "test_helper"

class ParallelBrewLoggingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @draft_key = SecureRandom.uuid
    @attributes = {
      method: "espresso", bean_id: beans(:open_household).id,
      grinder_id: equipment(:household_grinder).id, bean_weight_grams: "18",
      grind_setting: "1/2,50"
    }
  end

  test "JSON save acknowledges one coffee with a private URL and exact setting" do
    assert_difference [ "Brew.count", "InventoryAdjustment.count" ], 1 do
      post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    end

    assert_response :created
    saved = workspaces(:household).brews.find_by!(client_draft_key: @draft_key)
    assert_equal({ "url" => brew_path(saved) }, response.parsed_body)
    assert_equal "1/2,50", saved.grind_setting
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "retrying an acknowledged draft never deducts inventory twice" do
    post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    assert_response :created
    original_url = response.parsed_body.fetch("url")
    remaining = beans(:open_household).reload.remaining_grams

    assert_no_difference [ "Brew.count", "InventoryAdjustment.count", "ActivityEvent.count" ] do
      post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    end

    assert_response :success
    assert_equal original_url, response.parsed_body.fetch("url")
    assert_equal remaining, beans(:open_household).reload.remaining_grams
  end

  test "overlapping retries acknowledge a draft committed after the initial scoped lookup" do
    post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    assert_response :created
    original_url = response.parsed_body.fetch("url")
    remaining = beans(:open_household).reload.remaining_grams
    original_lookup = BrewsController.instance_method(:previously_saved_coffee)
    lookups = 0
    # Model the first request committing just after this request's early lookup.
    # The real scoped query runs again only after uniqueness rejects the save.
    BrewsController.define_method(:previously_saved_coffee) do
      lookups += 1
      lookups == 1 ? nil : original_lookup.bind_call(self)
    end
    BrewsController.send(:private, :previously_saved_coffee)

    assert_no_difference [ "Brew.count", "InventoryAdjustment.count", "ActivityEvent.count" ] do
      post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    end
    assert_response :ok
    assert_equal({ "url" => original_url }, response.parsed_body)
    assert_equal remaining, beans(:open_household).reload.remaining_grams
    assert_operator lookups, :>=, 2
  ensure
    if original_lookup
      BrewsController.define_method(:previously_saved_coffee, original_lookup)
      BrewsController.send(:private, :previously_saved_coffee)
    end
  end

  test "parallel coffee requiring confirmation cannot save unconfirmed whole beans with a grinder" do
    assert_no_difference [ "Brew.count", "InventoryAdjustment.count", "ActivityEvent.count" ] do
      post brews_path, params: { client_draft_key: @draft_key, grinder_confirmation_required: "1", brew: @attributes }, as: :json
    end
    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("errors"), I18n.t("brews.create.preparation_changed")
  end

  test "parallel coffee requiring confirmation accepts its matching grinder use" do
    use = confirm_grinding("1/2,50")
    post brews_path, params: { client_draft_key: @draft_key, grinder_confirmation_required: "1", grinder_use_id: use.id, brew: @attributes }, as: :json
    assert_response :created
    assert_equal use.occurred_at, workspaces(:household).brews.find_by!(client_draft_key: @draft_key).ground_at
  end

  test "confirmation requirement bypasses preparations without physical espresso grinding" do
    post brews_path, params: {
      client_draft_key: SecureRandom.uuid, grinder_confirmation_required: "1", brew: @attributes.merge(grinder_id: nil)
    }, as: :json
    assert_response :created

    beans(:open_household).update!(grind_state: "pre_ground")
    post brews_path, params: { client_draft_key: SecureRandom.uuid, grinder_confirmation_required: "1", brew: @attributes }, as: :json
    assert_response :created

    beans(:open_household).update!(grind_state: "whole_bean")
    post brews_path, params: {
      client_draft_key: SecureRandom.uuid, grinder_confirmation_required: "1",
      brew: @attributes.merge(method: "quick_drip", brewer_id: equipment(:household_brewer).id, machine_cups: 2)
    }, as: :json
    assert_response :created
  end

  test "validation errors retain the same retry key without consuming beans" do
    assert_no_difference [ "Brew.count", "InventoryAdjustment.count" ] do
      post brews_path, params: { client_draft_key: @draft_key, brew: @attributes.merge(bean_weight_grams: "") }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").any?
    post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    assert_response :created
  end

  test "malformed draft keys fail safely before creating a brew" do
    assert_no_difference "Brew.count" do
      post brews_path, params: { client_draft_key: "not-a-uuid", brew: @attributes }, as: :json
    end
    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").any?
  end

  test "structured draft keys are rejected without parsing them as UUIDs" do
    [ [ @draft_key ], { value: @draft_key } ].each do |key|
      assert_no_difference "Brew.count" do
        post brews_path, params: { client_draft_key: key, brew: @attributes }, as: :json
      end
      assert_response :unprocessable_entity
    end
  end

  test "the same client UUID cannot retrieve another user's brew" do
    existing = brews(:morning_espresso)
    existing.update!(user: users(:two), client_draft_key: @draft_key)

    assert_difference "Brew.count", 1 do
      post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json
    end

    assert_response :created
    assert_not_equal brew_path(existing), response.parsed_body.fetch("url")
  end

  test "foreign workspace draft keys do not reveal a brew" do
    foreign = brews(:other_workspace_brew)
    foreign.update!(client_draft_key: @draft_key)

    post brews_path, params: { client_draft_key: @draft_key, brew: @attributes }, as: :json

    assert_response :created
    assert_not_equal brew_path(foreign), response.parsed_body.fetch("url")
  end

  test "an invalid grinder confirmation cannot be silently ignored" do
    assert_no_difference [ "Brew.count", "InventoryAdjustment.count" ] do
      post brews_path, params: { client_draft_key: @draft_key, grinder_use_id: 0, brew: @attributes }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").any?
  end

  test "client provided ground_at is not trusted" do
    post brews_path, params: { client_draft_key: @draft_key, brew: @attributes.merge(ground_at: "2099-01-01T00:00:00Z") }, as: :json

    assert_response :created
    assert_nil workspaces(:household).brews.find_by!(client_draft_key: @draft_key).ground_at
  end

  test "saving coffees in reverse order preserves confirmed grinding order and text" do
    first = nil
    second = nil
    travel_to Time.current.change(usec: 0) do
      first = confirm_grinding("1/2,50")
    end
    travel_to 1.minute.from_now.change(usec: 0) do
      second = confirm_grinding("1/2,75")
    end
    post brews_path, params: {
      client_draft_key: SecureRandom.uuid, grinder_use_id: second.id,
      brew: @attributes.merge(grind_setting: "1/2,75", occurred_at: 1.hour.from_now.iso8601)
    }, as: :json
    assert_response :created
    post brews_path, params: {
      client_draft_key: @draft_key, grinder_use_id: first.id,
      brew: @attributes.merge(occurred_at: 2.hours.from_now.iso8601)
    }, as: :json
    assert_response :created

    saved_first = workspaces(:household).brews.find_by!(client_draft_key: @draft_key)
    assert_equal first.occurred_at, saved_first.ground_at
    assert_equal "1/2,50", saved_first.grind_setting
    get grinder_history_brews_path, params: { method: "espresso" }, as: :json
    assert_equal "1/2,75", response.parsed_body.fetch("last_uses").fetch(equipment(:household_grinder).id.to_s).fetch("setting")
    get new_brew_path(method: "espresso")
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "1/2,75"
  end

  test "another household member's confirmation cannot be claimed" do
    use = confirm_grinding("1/2,50", user: users(:two))
    assert_no_difference "Brew.count" do
      post brews_path, params: { client_draft_key: @draft_key, grinder_use_id: use.id, brew: @attributes }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "editing a confirmed setting requires confirmation again" do
    use = confirm_grinding("1/2,50")
    assert_no_difference [ "Brew.count", "InventoryAdjustment.count" ] do
      post brews_path, params: {
        client_draft_key: @draft_key, grinder_use_id: use.id, brew: @attributes.merge(grind_setting: "1/2,500")
      }, as: :json
    end
    assert_response :unprocessable_entity
  end

  private
    def confirm_grinding(setting, user: users(:one))
      workspaces(:household).grinder_uses.create!(
        user:, bean: beans(:open_household), grinder: equipment(:household_grinder),
        method: "espresso", grind_setting: setting, confirmation_key: SecureRandom.uuid
      )
    end
end
