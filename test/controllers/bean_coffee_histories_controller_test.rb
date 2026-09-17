require "test_helper"

class BeanCoffeeHistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @bean = beans(:open_household)
    @workspace = workspaces(:household)
  end

  test "matching names stay separate unless sharing is explicitly selected" do
    assert_difference "CoffeeHistory.count", 1 do
      post beans_path, params: { bean: attributes }
    end
    independent = @workspace.beans.order(:id).last
    assert_redirected_to bean_path(independent)
    assert_not_equal @bean.coffee_history_id, independent.coffee_history_id

    assert_no_difference "CoffeeHistory.count" do
      post beans_path, params: { bean: attributes.merge(coffee_history_choice: @bean.coffee_history_id) }
    end
    linked = @workspace.beans.order(:id).last
    assert_redirected_to bean_path(linked)
    assert_equal @bean.coffee_history_id, linked.coffee_history_id
  end

  test "editing links only the selected bag and can start a separate history" do
    other = beans(:second_open_household)
    original = other.coffee_history_id
    patch bean_path(other), params: { bean: { coffee_history_choice: @bean.coffee_history_id } }
    assert_redirected_to bean_path(other)
    assert_equal @bean.coffee_history_id, other.reload.coffee_history_id
    event = ActivityEvent.where(subject: other, action: "bean.updated").last
    assert_equal true, event.metadata["coffee_history_changed"]
    assert_difference "CoffeeHistory.count", 1 do
      patch bean_path(other), params: { bean: { coffee_history_choice: "separate" } }
    end
    assert_redirected_to bean_path(other)
    assert_not_equal @bean.coffee_history_id, other.reload.coffee_history_id
    assert_not_equal original, other.coffee_history_id
  end

  test "renaming does not change sharing and raw history id cannot be mass assigned" do
    original = @bean.coffee_history_id
    patch bean_path(@bean), params: { bean: { name: "New name", coffee_history_id: beans(:second_open_household).coffee_history_id } }
    assert_redirected_to bean_path(@bean)
    assert_equal original, @bean.reload.coffee_history_id
  end

  test "invalid save creates no history and retains the submitted sharing choice" do
    assert_no_difference [ "CoffeeHistory.count", "Bean.count" ] do
      post beans_path, params: { bean: attributes.merge(name: "", coffee_history_choice: @bean.coffee_history_id) }
    end
    assert_response :unprocessable_entity
    assert_select "select[name='bean[coffee_history_choice]'] option[selected][value=?]", @bean.coffee_history_id.to_s
    assert_no_difference "CoffeeHistory.count" do
      patch bean_path(@bean), params: { bean: { name: "", coffee_history_choice: "separate" } }
    end
    assert_response :unprocessable_entity
  end

  test "foreign nonexistent and malformed choices fail closed" do
    [ beans(:other_workspace_open).coffee_history_id, "999999999999", "1 OR 1=1" ].each do |choice|
      assert_no_difference [ "CoffeeHistory.count", "Bean.count" ] do
        post beans_path, params: { bean: attributes.merge(coffee_history_choice: choice) }
      end
      assert_response :not_found
    end
    post beans_path, params: { bean: attributes.merge(coffee_history_choice: [ @bean.coffee_history_id ]) }
    assert_response :bad_request
  end

  test "suggestions normalize both names and distinguish independent matching groups" do
    duplicate = @bean.duplicate_for_new_bag!
    independent = @workspace.beans.create!(attributes.merge(name: " HOUSE   Blend ", roaster_name: " good  coffee "))
    foreign = beans(:other_workspace_open)
    foreign.update!(name: @bean.name, roaster_name: @bean.roaster_name)
    get coffee_history_suggestions_beans_path, params: { name: " house blend ", roaster_name: "GOOD COFFEE" }, as: :json
    assert_response :success
    suggestions = response.parsed_body.fetch("suggestions")
    assert_equal [ @bean.coffee_history_id, independent.coffee_history_id ].sort, suggestions.map { |row| row["id"] }.sort
    assert_equal 2, suggestions.find { |row| row["id"] == duplicate.coffee_history_id }.fetch("bag_count")
    assert suggestions.all? { |row| row["label"].present? }
    get coffee_history_suggestions_beans_path, params: { name: @bean.name, roaster_name: "" }, as: :json
    assert_empty response.parsed_body.fetch("suggestions")
  end

  test "suggestions for edits exclude the current history and reject foreign bean ids" do
    get coffee_history_suggestions_beans_path, params: { name: @bean.name, roaster_name: @bean.roaster_name, bean_id: @bean.id }, as: :json
    assert_response :success
    assert_empty response.parsed_body.fetch("suggestions")
    get coffee_history_suggestions_beans_path, params: { name: @bean.name, roaster_name: @bean.roaster_name, bean_id: beans(:other_workspace_open).id }, as: :json
    assert_response :not_found
  end

  test "viewers cannot fetch suggestions or change memberships" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: @workspace)
    sign_in_as(users(:two))
    get coffee_history_suggestions_beans_path, params: { name: @bean.name, roaster_name: @bean.roaster_name }, as: :json
    assert_redirected_to root_path
    patch bean_path(@bean), params: { bean: { coffee_history_choice: "separate" } }
    assert_redirected_to root_path
  end

  private
    def attributes
      { name: @bean.name, roaster_name: @bean.roaster_name, bag_size_grams: 250, remaining_grams: 250 }
    end
end
