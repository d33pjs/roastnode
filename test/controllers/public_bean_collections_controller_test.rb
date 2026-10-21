require "test_helper"

class PublicBeanCollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:household)
    @bean = beans(:open_household)
    @user = users(:one)
  end

  test "owner can save preview and publish a collection without exposing private fields" do
    sign_in_as(@user)
    patch public_bean_collection_path, params: { public_bean_collection: {
      title: "Our favorite coffees", description: "Tasted at home", enabled: "0", mode: "automatic",
      publish_bean_ids: [ @bean.id ]
    } }
    assert_redirected_to edit_public_bean_collection_path
    collection = @workspace.reload.public_bean_collection
    assert_not collection.enabled?
    get preview_public_bean_collection_path
    assert_response :success
    assert_select "h1", "Our favorite coffees"
    patch public_bean_collection_path, params: { public_bean_collection: {
      title: collection.title, enabled: "1", mode: "automatic"
    } }
    sign_out
    get public_bean_collection_page_path(collection.token)
    assert_response :success
    assert_select "h1", "Our favorite coffees"
    assert_not_includes response.body, @bean.notes
    assert_not_includes response.body, @user.email_address
    assert_select "meta[name=robots][content='noindex, nofollow']"
  end

  test "members and viewers cannot manage collection or publish bags" do
    sign_in_as(@user)
    @workspace.memberships.find_by!(user: @user).update!(role: "member")
    patch public_bean_collection_path, params: { public_bean_collection: { title: "No", publish_bean_ids: [ @bean.id ] } }
    assert_redirected_to root_path
    assert_nil @workspace.reload.public_bean_collection
    @workspace.memberships.find_by!(user: @user).update!(role: "viewer")
    get edit_public_bean_collection_path
    assert_redirected_to root_path
  end

  test "foreign selections and publication requests fail without partial writes" do
    sign_in_as(@user)
    patch public_bean_collection_path, params: { public_bean_collection: {
      title: "No", mode: "automatic", publish_bean_ids: [ @bean.id, beans(:other_workspace_open).id ]
    } }
    assert_response :not_found
    assert_nil @bean.reload.public_bean_share
    assert_nil @workspace.reload.public_bean_collection
  end

  test "disabled unknown and newly protected sources fail closed" do
    collection = @workspace.create_public_bean_collection!(title: "Safe", enabled: false)
    get public_bean_collection_page_path(collection.token)
    assert_response :not_found
    get public_bean_collection_page_path("unknown")
    assert_response :not_found
    share = @bean.create_public_bean_share!(workspace: @workspace, created_by: @user, updated_by: @user, enabled: true, title: "Safe")
    PublicBeanShareRefresher.refresh(share)
    collection.update!(enabled: true, mode: "automatic")
    share.update_columns(password_digest: BCrypt::Password.create("secret"))
    get public_bean_collection_page_path(collection.token)
    assert_response :success
    assert_not_includes response.body, @bean.name
  end

  test "linking published bags changes grouping and never reveals an unpublished sibling" do
    sign_in_as(@user)
    first = @bean.create_public_bean_share!(workspace: @workspace, created_by: @user, updated_by: @user, enabled: true, title: "First")
    second_bean = beans(:second_open_household)
    second = second_bean.create_public_bean_share!(workspace: @workspace, created_by: @user, updated_by: @user, enabled: true, title: "Second")
    [ first, second ].each { |share| PublicBeanShareRefresher.refresh(share) }
    collection = @workspace.create_public_bean_collection!(title: "Our coffees", mode: "automatic", enabled: true)
    hidden = @bean.duplicate_for_new_bag!
    hidden.update!(bag_size_grams: 9999)
    assert_equal 2, collection.snapshot["groups"].size
    patch bean_group_link_path(second_bean), params: { bean_group_link: { target_bean_id: @bean.id } }
    group = collection.reload.snapshot["groups"].sole
    assert_equal 2, group["bag_count"]
    assert_equal "500.0", group["total_grams"]
    assert_not_includes group.to_json, "9999"
  end

  test "bulk publication always saves a draft before enabling and protected exclusions persist" do
    sign_in_as(@user)
    patch public_bean_collection_path, params: { public_bean_collection: {
      title: "Draft first", mode: "automatic", enabled: "1", publish_bean_ids: [ @bean.id ]
    } }
    assert_redirected_to edit_public_bean_collection_path
    collection = @workspace.reload.public_bean_collection
    refute collection.enabled?
    share = @bean.reload.public_bean_share
    collection.update!(excluded_share_ids: [ share.id ], excluded_history_ids: [ @bean.coffee_history_id ])
    share.update!(password: "locked")
    patch public_bean_collection_path, params: { public_bean_collection: {
      title: "Renamed", mode: "automatic", enabled: "1", excluded_share_ids: [ "" ], excluded_history_ids: [ "" ]
    } }
    assert_redirected_to edit_public_bean_collection_path
    assert_equal [ share.id ], collection.reload.excluded_share_ids
    assert_equal [ @bean.coffee_history_id ], collection.excluded_history_ids
    share.update!(password_digest: nil)
    assert_empty collection.reload.snapshot["groups"]
  end

  test "collection tokens are redacted from request paths and redirects" do
    request = ActionDispatch::Request.new("PATH_INFO" => "/l/secret-token", "QUERY_STRING" => "view=all")
    assert_equal "/l/[FILTERED]?view=all", request.filtered_path
  end
end
