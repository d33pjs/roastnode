require "test_helper"

class PublicBeanCollectionTest < ActiveSupport::TestCase
  test "collection settings are private by default and reject foreign references" do
    workspace = workspaces(:household)
    collection = workspace.build_public_bean_collection(title: "Our coffees")
    assert collection.valid?
    refute collection.enabled?
    assert_equal "selected", collection.mode
    assert collection.token.present?
    assert_not_equal collection.token, collection.token_digest
    foreign = beans(:other_workspace_open).create_public_bean_share!(workspace: workspaces(:other_household),
      created_by: users(:two), updated_by: users(:two), title: "Foreign", enabled: true)
    collection.selected_share_ids = [ foreign.id ]
    refute collection.valid?
  end

  test "source deletion removes bags immediately and keeps other groups" do
    workspace = workspaces(:household)
    user = users(:one)
    first, second = [ :open_household, :second_open_household ].map do |key|
      bean = beans(key)
      share = bean.create_public_bean_share!(workspace:, created_by: user, updated_by: user, title: bean.name, enabled: true)
      PublicBeanShareRefresher.refresh(share)
      share
    end
    collection = workspace.create_public_bean_collection!(title: "Our coffees", mode: "automatic")
    assert_equal 2, collection.snapshot["groups"].size
    first.destroy!
    assert_equal [ second.token ], collection.reload.snapshot["groups"].flat_map { |group| group["bags"].map { |bag| bag["share_token"] } }
  end

  test "unpublishable source is disabled and source batches rebuild the collection once" do
    workspace = workspaces(:household)
    user = users(:one)
    shares = [ :open_household, :second_open_household ].map do |key|
      bean = beans(key)
      share = bean.create_public_bean_share!(workspace:, created_by: user, updated_by: user, title: bean.name, enabled: true)
      PublicBeanShareRefresher.refresh(share)
      share
    end
    collection = workspace.create_public_bean_collection!(title: "Our coffees", mode: "automatic")
    updates = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      updates << payload[:sql] if payload[:sql].match?(/UPDATE "public_bean_collections"/)
    end
    begin
      PublicBeanShareRefresher.refresh_comparisons_for(workspace)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
    assert_equal 1, updates.size
    shares.first.bean.update!(opened_on: nil)
    PublicBeanShareRefresher.refresh(shares.first)
    refute shares.first.reload.enabled?
    assert_equal 1, collection.reload.snapshot["groups"].size
  end

  test "public prices validate independently of private costs" do
    bean = beans(:open_household)
    share = bean.build_public_bean_share(workspace: bean.workspace, created_by: users(:one), updated_by: users(:one), title: bean.name)
    share.public_price = "12,50"
    refute share.valid?
    share.assign_attributes(public_price_currency: "EUR", public_price_recorded_on: Date.current)
    assert share.valid?
    assert_equal 1250, share.public_price_cents
    %w[wrong NaN Infinity -Infinity].each do |value|
      share.public_price = value
      refute share.valid?
    end
    share.public_price = ""
    assert share.valid?
    assert_nil share.public_price_payload
  end
end
