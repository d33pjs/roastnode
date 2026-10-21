require "test_helper"

class PublicBeanCollectionSnapshotBuilderTest < ActiveSupport::TestCase
  include PhotoTestHelper

  setup do
    @workspace = workspaces(:household)
    @user = users(:one)
    @bean = beans(:open_household)
  end

  test "groups duplicate bags and computes bag and individual brew averages" do
    @bean.update!(rating: 4, notes: "NEVER PUBLIC", purchase_price_cents: 98765)
    first = publish(@bean)
    linked = @bean.duplicate_for_new_bag!
    linked.update!(bag_size_grams: 1000, remaining_grams: 1000, rating: 5, opened_on: Date.new(2026, 9, 1))
    second = publish(linked)
    third_bag = linked.duplicate_for_new_bag!
    third_bag.update!(rating: 3, opened_on: Date.new(2026, 10, 1))
    third = publish(third_bag)
    2.times do
      @workspace.brews.create!(user: @user, bean: linked, method: "espresso", bean_weight_grams: 1,
        grinder: equipment(:household_grinder), machine: equipment(:household_machine), rating: 5)
    end
    PublicBeanShareRefresher.refresh(second)
    collection = @workspace.create_public_bean_collection!(title: "Favorites", mode: "selected",
      selected_share_ids: [ first.id, second.id, third.id ], representative_share_ids: [ second.id ])

    group = collection.snapshot.fetch("groups").sole
    assert_equal 3, group["bag_count"]
    assert_equal "2250.0", group["total_grams"]
    assert_equal "4.0", group["bean_rating"]
    assert_equal "4.7", group["brew_average"]
    assert_equal 3, group["rated_brew_count"]
    assert_equal 1, group["rank"]
    assert_equal [ "2026-05-10", "2026-09-01", "2026-10-01" ], group["bags"].map { |bag| bag["opened_on"] }
    assert_no_match(/NEVER PUBLIC|98765|purchase_price|attachment_id|coffee_history_id|bean_id|user_email/, collection.snapshot.to_json)
  end

  test "automatic mode excludes private protected disabled foreign and explicitly excluded bags" do
    included = publish(@bean)
    excluded = publish(beans(:second_open_household))
    protected_share = publish(beans(:archived_household), password: "secret")
    publish(beans(:other_workspace_open))
    collection = @workspace.create_public_bean_collection!(title: "Public", mode: "automatic",
      excluded_share_ids: [ excluded.id ])
    assert_equal [ included.token ], collection.snapshot["groups"].flat_map { |group| group["bags"].map { |bag| bag["share_token"] } }
    refute_includes collection.snapshot.to_json, protected_share.token
    included.update!(enabled: false)
    assert_empty collection.reload.snapshot["groups"]
  end

  test "public prices are deliberate and media only uses approved opaque paths" do
    photo = attach_photo(@bean)
    share = publish(@bean, selected_photo_attachment_ids: [ photo.id ], public_price: "14,90",
      public_price_currency: "EUR", public_price_recorded_on: Date.new(2026, 10, 21))
    collection = @workspace.create_public_bean_collection!(title: "Photos", mode: "automatic")
    bag = collection.snapshot["groups"].sole["bags"].sole
    assert_equal "14.90", bag.dig("public_price", "amount")
    assert_equal "59.60", bag.dig("public_price", "per_kg")
    assert_match(%r{\A/b/[^/]+/media/[^/]+}, bag["photos"].sole["url"])
    assert_no_match(/active_storage|photo.jpg|attachment_id/, bag.to_json)
    share.update!(password: "now locked")
    assert_empty collection.reload.snapshot["groups"]
  end

  test "unrated bags do not become zero and equal ranks use competition ranking" do
    @bean.update!(rating: 4)
    publish(@bean)
    other = beans(:second_open_household)
    other.update!(rating: 4)
    publish(other)
    publish(beans(:archived_household))
    collection = @workspace.create_public_bean_collection!(title: "Rank", mode: "automatic")
    groups = collection.snapshot["groups"]
    assert_equal [ 1, 2, nil ], groups.map { |group| group["rank"] }
    assert_nil groups.last["bean_rating"]
  end

  test "equal rounded metrics share a rank and unrated coffees stay below rated coffees" do
    @bean.update!(rating: 4)
    other = beans(:second_open_household)
    other.update!(rating: 4)
    @workspace.brews.create!(user: @user, bean: other, method: "espresso", bean_weight_grams: 1,
      grinder: equipment(:household_grinder), machine: equipment(:household_machine), rating: 4)
    publish(@bean)
    publish(other)
    low = beans(:archived_household)
    low.update!(rating: 3)
    publish(low)
    collection = @workspace.create_public_bean_collection!(title: "Ties", mode: "automatic")
    assert_equal [ 1, 1, 3 ], collection.snapshot["groups"].map { |group| group["rank"] }
  end

  test "only unprotected enabled public brew links are listed" do
    brew = brews(:morning_espresso)
    brew_share = brew.create_public_brew_share!(workspace: @workspace, created_by: @user, updated_by: @user,
      title: "Our best shot", enabled: true)
    source = publish(@bean)
    collection = @workspace.create_public_bean_collection!(title: "Links", mode: "automatic")
    assert_equal [ brew_share.token ], collection.snapshot["groups"].sole["public_brews"].map { |row| row["token"] }
    brew_share.update_columns(password_digest: BCrypt::Password.create("hidden"))
    assert_empty collection.public_snapshot["groups"].sole["public_brews"]
    PublicBeanShareRefresher.refresh(source)
    assert_empty collection.reload.snapshot["groups"].sole["public_brews"]
  end

  private
    def publish(bean, **attributes)
      price = attributes.delete(:public_price)
      share = bean.build_public_bean_share(workspace: bean.workspace, title: "Public #{bean.name}",
        created_by: @user, updated_by: @user, enabled: true, **attributes)
      share.public_price = price if price
      share.refresh_snapshot!(title: share.title, selected_photo_attachment_ids: share.selected_photo_attachment_ids,
        updated_by: @user)
      share
    end
end
