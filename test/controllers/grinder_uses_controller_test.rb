require "test_helper"

class GrinderUsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @attributes = { bean_id: beans(:open_household).id, grinder_id: equipment(:household_grinder).id,
      method: "espresso", grind_setting: "1/2,50", confirmation_key: SecureRandom.uuid }
  end

  test "confirmation is private exact text server timed and inventory neutral" do
    before_inventory = beans(:open_household).remaining_grams
    travel_to Time.current.change(usec: 0) do
      post "/grinder_uses", params: { grinder_use: @attributes.merge(occurred_at: 1.year.ago.iso8601, user_id: users(:two).id) }, as: :json
      assert_response :created
      payload = response.parsed_body
      assert_equal "1/2,50", payload.dig("use", "grind_setting")
      assert_equal Time.current, Time.iso8601(payload.dig("use", "occurred_at"))
      assert_equal "1/2,50", payload.dig("last_uses", equipment(:household_grinder).id.to_s, "setting")
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal @user.id, GrinderUse.find(payload.dig("use", "id")).user_id
      assert_equal before_inventory, beans(:open_household).reload.remaining_grams
    end
  end

  test "latest grinder snapshot preserves exact surrounding text for the next coffee" do
    @attributes[:grind_setting] = " 1/2,50 "
    post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
    assert_response :created
    assert_equal " 1/2,50 ", response.parsed_body.dig("last_uses", equipment(:household_grinder).id.to_s, "setting")
  end

  test "retry returns original id and time but rejects changed context" do
    post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
    assert_response :created
    original = response.parsed_body.fetch("use")
    travel 10.minutes do
      assert_no_difference -> { GrinderUse.count } do
        post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
        assert_response :ok
      end
      assert_equal original, response.parsed_body.fetch("use")
      %i[bean_id grinder_id method grind_setting].each do |attribute|
        changed = { bean_id: beans(:second_open_household).id,
          grinder_id: equipment(:household_machine).id, method: "quick_drip", grind_setting: "1/2,5" }.fetch(attribute)
        post "/grinder_uses", params: { grinder_use: @attributes.merge(attribute => changed) }, as: :json
        assert_response :unprocessable_entity
      end
    end
  end

  test "references remain active workspace scoped" do
    [ { bean_id: beans(:other_workspace_open).id }, { grinder_id: equipment(:other_workspace_grinder).id } ].each do |foreign|
      post "/grinder_uses", params: { grinder_use: @attributes.merge(foreign) }, as: :json
      assert_response :not_found
    end
  end

  test "viewer cannot confirm and member can" do
    memberships(:owner).update!(role: "viewer")
    post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
    assert_redirected_to root_path
    sign_in_as(users(:two))
    users(:two).update!(active_workspace: workspaces(:household))
    post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
    assert_response :created
  end

  test "blank setting records an unknown position and keys remain scoped to their operator" do
    post "/grinder_uses", params: { grinder_use: @attributes.merge(grind_setting: "") }, as: :json
    assert_response :created
    first = response.parsed_body.dig("use", "id")
    assert_equal "", response.parsed_body.dig("last_uses", equipment(:household_grinder).id.to_s, "setting")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    post "/grinder_uses", params: { grinder_use: @attributes }, as: :json
    assert_response :created
    assert_not_equal first, response.parsed_body.dig("use", "id")
  end

  test "invalid confirmation keys and methods are rejected" do
    [ { confirmation_key: "invalid" }, { confirmation_key: { bad: "shape" } }, { confirmation_key: [ "bad" ] }, { method: "unknown" } ].each do |invalid|
      post "/grinder_uses", params: { grinder_use: @attributes.merge(invalid) }, as: :json
      assert_response :unprocessable_entity
    end
  end
end
