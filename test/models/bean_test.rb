require "test_helper"

class BeanTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "defaults remaining grams to bag size" do
    bean = workspaces(:household).beans.create!(
      name: "La Marianela",
      roaster_name: "Fjord",
      bag_size_grams: 250
    )

    assert_equal 250.to_d, bean.remaining_grams
  end

  test "open scope returns opened unarchived beans with remaining inventory first by opened date" do
    beans(:open_household).update!(opened_on: Date.new(2026, 5, 1))
    beans(:second_open_household).update!(opened_on: Date.new(2026, 5, 2))
    stock = workspaces(:household).beans.create!(
      name: "Pantry Bag",
      roaster_name: "Good Coffee",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )
    used_up = workspaces(:household).beans.create!(
      name: "Finished But Kept",
      roaster_name: "Good Coffee",
      bag_size_grams: 250,
      remaining_grams: 0,
      opened_on: Date.new(2026, 5, 3)
    )

    assert_equal [ beans(:open_household), beans(:second_open_household) ], workspaces(:household).beans.open.to_a
    assert_not_includes workspaces(:household).beans.open, stock
    assert_not_includes workspaces(:household).beans.open, used_up
    assert_not_includes workspaces(:household).beans.open, beans(:archived_household)
    assert_not_includes workspaces(:household).beans.open, beans(:other_workspace_open)
  end

  test "derives bag status from opened remaining and archived state" do
    stock = workspaces(:household).beans.create!(
      name: "Pantry Bag",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )
    open = beans(:open_household)
    used_up = workspaces(:household).beans.create!(
      name: "Finished But Kept",
      bag_size_grams: 250,
      remaining_grams: 0,
      opened_on: Date.current
    )
    archived = beans(:archived_household)

    assert_equal "stock", stock.bag_status
    assert_equal "open", open.bag_status
    assert_equal "used_up", used_up.bag_status
    assert_equal "archived", archived.bag_status
  end

  test "unsaved bean with an opened date defaults to open status for forms" do
    bean = workspaces(:household).beans.new(opened_on: Date.current)

    assert_equal "open", bean.bag_status
  end

  test "applies selected bag status to lifecycle fields" do
    bean = workspaces(:household).beans.build(
      name: "Pantry Bag",
      bag_size_grams: 250,
      remaining_grams: 0,
      opened_on: Date.current
    )

    bean.apply_bag_status("stock")
    assert_nil bean.opened_on
    assert_nil bean.archived_at
    assert_equal 250.to_d, bean.remaining_grams
    assert_equal "stock", bean.bag_status

    bean.apply_bag_status("open")
    assert_equal Date.current, bean.opened_on
    assert_nil bean.archived_at
    assert_equal 250.to_d, bean.remaining_grams
    assert_equal "open", bean.bag_status

    bean.apply_bag_status("used_up")
    assert_equal 0.to_d, bean.remaining_grams
    assert_nil bean.archived_at
    assert_equal "used_up", bean.bag_status

    bean.apply_bag_status("archived")
    assert_not_nil bean.archived_at
    assert_equal "archived", bean.bag_status
  end

  test "accepts rich bean metadata" do
    bean = workspaces(:household).beans.create!(
      name: "El Paraiso",
      roaster_name: "Fjord",
      bag_size_grams: 250,
      purchased_on: Date.new(2026, 5, 1),
      roast_date: Date.new(2026, 5, 10),
      roast_type: "espresso",
      roast_degree: 3.5,
      rating: 5,
      blend_type: "single_origin",
      tasting_notes: "Peach, cacao, syrup",
      decaffeinated: true,
      purchase_url: "https://example.com/el-paraiso",
      notes: "Rest 14 days.",
      country: "Colombia",
      region: "Cauca",
      farm: "El Paraiso",
      farmer: "Diego Bermudez",
      elevation: "1,930 masl",
      variety: "Castillo",
      process: "thermal shock washed",
      harvested: "2025/2026",
      blend_percentage: "100%"
    )

    assert_equal "espresso", bean.roast_type
    assert_equal 3.5.to_d, bean.roast_degree
    assert_equal "single_origin", bean.blend_type
    assert_predicate bean, :decaffeinated?
    assert_equal "Colombia", bean.country
    assert_equal "100%", bean.blend_percentage
  end

  test "validates rich bean metadata options" do
    bean = workspaces(:household).beans.build(
      name: "Broken Bean",
      bag_size_grams: 250,
      roast_type: "turbo",
      blend_type: "mystery",
      roast_degree: 5.5,
      rating: 6
    )

    assert_not bean.valid?
    assert_includes bean.errors[:roast_type], "is not included in the list"
    assert_includes bean.errors[:blend_type], "is not included in the list"
    assert_includes bean.errors[:roast_degree], "must be less than or equal to 5"
    assert_includes bean.errors[:rating], "must be in 1..5"
  end

  test "rating is blank or an integer from one through five" do
    bean = workspaces(:household).beans.build(
      name: "Rated Bag",
      bag_size_grams: 250
    )

    [ nil, 1, 2, 3, 4, 5 ].each do |rating|
      bean.rating = rating
      assert_predicate bean, :valid?, "expected #{rating.inspect} to be valid"
    end

    [ 0, 6 ].each do |rating|
      bean.rating = rating
      assert_not_predicate bean, :valid?, "expected #{rating.inspect} to be invalid"
      assert_includes bean.errors[:rating], "must be in 1..5"
    end

    [ 1.5, "2.5" ].each do |rating|
      bean.rating = rating
      assert_not_predicate bean, :valid?, "expected #{rating.inspect} to be invalid"
      assert_includes bean.errors[:rating], "must be an integer"
    end
  end

  test "grind state defaults to whole bean and supports pre ground" do
    bean = workspaces(:household).beans.new(
      name: "Ground filter",
      bag_size_grams: 250,
      remaining_grams: 250
    )

    assert_equal "whole_bean", bean.grind_state
    assert_predicate bean, :valid?

    bean.grind_state = "pre_ground"
    assert_predicate bean, :valid?

    bean.grind_state = "powder_cloud"
    assert_not_predicate bean, :valid?
  end

  test "can close and reopen a bean bag" do
    bean = beans(:archived_household)

    bean.reopen!
    assert_nil bean.archived_at
    assert_equal bean.bag_size_grams, bean.remaining_grams

    bean.close!
    assert_not_nil bean.archived_at
  end

  test "archive tolerates legacy invalid purchase url" do
    freeze_time do
      bean = beans(:open_household)
      bean.update_column(:purchase_url, "javascript:alert('bean')")

      bean.archive!

      bean.reload
      assert_equal Time.current, bean.archived_at
      assert_nil bean.finished_at
      assert_equal "javascript:alert('bean')", bean.purchase_url
    end
  end

  test "finish marks a bag finished while preserving leftover grams" do
    freeze_time do
      bean = beans(:open_household)
      bean.update!(remaining_grams: 14)

      bean.finish!

      assert_equal "finished", bean.bag_status
      assert_equal Time.current, bean.finished_at
      assert_equal 14.to_d, bean.remaining_grams
      assert_nil bean.archived_at
    end
  end

  test "reopen clears finished and archived lifecycle fields" do
    bean = beans(:open_household)
    bean.update!(remaining_grams: 14)
    bean.finish!

    bean.reopen!

    assert_equal "open", bean.bag_status
    assert_nil bean.finished_at
    assert_nil bean.archived_at
    assert_equal 14.to_d, bean.remaining_grams
  end

  test "reopen tolerates legacy invalid purchase url" do
    travel_to Date.new(2026, 6, 13) do
      bean = beans(:open_household)
      bean.update_columns(
        purchase_url: "javascript:alert('bean')",
        remaining_grams: 0,
        archived_at: Time.current,
        finished_at: Time.current,
        opened_on: nil
      )

      bean.reopen!

      bean.reload
      assert_equal "open", bean.bag_status
      assert_equal bean.bag_size_grams, bean.remaining_grams
      assert_equal Date.new(2026, 6, 13), bean.opened_on
      assert_nil bean.archived_at
      assert_nil bean.finished_at
      assert_equal "javascript:alert('bean')", bean.purchase_url
    end
  end

  test "finished stats use consumed grams and clamped open days" do
    bean = beans(:open_household)
    bean.update!(
      bag_size_grams: 250,
      remaining_grams: 14,
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 23, 9)
    )

    assert_equal 236.to_d, bean.finished_used_grams
    assert_equal 13, bean.finished_open_days
    assert_equal BigDecimal("18.15"), bean.finished_grams_per_day
    assert bean.nearly_finished?
  end

  test "duplicates a bean as full unopened stock with metadata urls notes and photos" do
    source = beans(:open_household)
    source.update!(
      grind_state: "pre_ground",
      remaining_grams: 12,
      purchase_price_cents: 1490,
      purchase_url: "https://shop.example/house-blend",
      coffee_origin_url: "https://origin.example/house-blend",
      notes: "Private resting note.",
      public_note: "Public tasting note."
    )
    source.update_columns(
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 6, 1, 9),
      archived_at: Time.zone.local(2026, 6, 2, 9)
    )
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      source.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
    end
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      source.photos.attach(io: file, filename: "label.jpg", content_type: "image/jpeg")
    end
    source.set_primary_photo!(source.photos.last)
    source_attachment_ids = source.photos.attachments.order(:id).ids
    source_blob_ids = source.photos.attachments.order(:id).pluck(:blob_id)
    source_primary = source.primary_photo_attachment
    source_remaining = source.remaining_grams
    source_inventory_adjustment_ids = source.inventory_adjustment_ids
    copied_attributes = %w[
      name roaster_name origin process roast_date roast_level tasting_notes bag_size_grams
      purchase_source purchase_url coffee_origin_url purchased_on purchase_price_cents rating notes public_note
      roast_type roast_degree blend_type decaffeinated grind_state country continent region farm farmer elevation
      variety harvested blend_percentage country_of_manufacturer manufacturer
    ]
    duplicate = nil

    assert_no_difference -> { InventoryAdjustment.count } do
      assert_no_difference -> { ActiveStorage::Blob.count } do
        assert_difference -> { ActiveStorage::Attachment.count }, 2 do
          duplicate = source.duplicate_for_new_bag!
        end
      end
    end

    assert_not_equal source.id, duplicate.id
    assert_equal source.workspace, duplicate.workspace
    assert_equal source.attributes.slice(*copied_attributes), duplicate.attributes.slice(*copied_attributes)
    assert_equal "stock", duplicate.bag_status
    assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
    assert_nil duplicate.opened_on
    assert_nil duplicate.finished_at
    assert_nil duplicate.archived_at
    assert_equal source, duplicate.duplicated_from_bean
    assert_equal 2, duplicate.photos.count
    assert_equal source_blob_ids, duplicate.photos.attachments.order(:id).pluck(:blob_id)
    assert_empty source_attachment_ids & duplicate.photos.attachments.ids
    assert_not_equal source_primary.id, duplicate.primary_photo_attachment.id
    assert_equal source_primary.blob_id, duplicate.primary_photo_attachment.blob_id
    assert_equal duplicate, duplicate.primary_photo_attachment.record
    assert_nil duplicate.public_bean_share
    assert_equal source_remaining, source.reload.remaining_grams
    assert_equal source_inventory_adjustment_ids, source.inventory_adjustment_ids
    assert_not_includes source.workspace.beans.open, duplicate
  end

  test "duplicates copy new origin and manufacturer metadata" do
    source = beans(:open_household)
    source.update!(
      continent: "South America",
      country_of_manufacturer: "Germany",
      manufacturer: "Calendar Coffee"
    )

    duplicate = source.duplicate_for_new_bag!

    assert_equal "South America", duplicate.continent
    assert_equal "Germany", duplicate.country_of_manufacturer
    assert_equal "Calendar Coffee", duplicate.manufacturer
  end

  test "duplicates drop both legacy invalid private urls" do
    source = beans(:open_household)
    source.update_columns(
      purchase_url: "javascript:alert('bean')",
      coffee_origin_url: "data:text/html,<p>bean</p>"
    )

    duplicate = nil
    assert_difference -> { source.workspace.beans.count }, 1 do
      duplicate = source.duplicate_for_new_bag!
    end

    assert_nil duplicate.purchase_url
    assert_nil duplicate.coffee_origin_url
  end

  test "duplicates keep valid purchase url" do
    source = beans(:open_household)
    source.update!(purchase_url: "https://example.com/beans")

    duplicate = source.duplicate_for_new_bag!

    assert_equal "https://example.com/beans", duplicate.purchase_url
  end

  test "open bag transition opens stock today and preserves remaining inventory" do
    travel_to Date.new(2026, 6, 13) do
      bean = workspaces(:household).beans.create!(
        name: "Shelf Bag",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 250,
        remaining_grams: 172,
        opened_on: nil
      )

      bean.open_bag!

      assert_equal "open", bean.bag_status
      assert_equal Date.new(2026, 6, 13), bean.opened_on
      assert_equal 172.to_d, bean.remaining_grams
      assert_nil bean.archived_at
      assert_nil bean.finished_at
    end
  end

  test "open bag transition tolerates legacy invalid purchase url" do
    travel_to Date.new(2026, 6, 13) do
      bean = workspaces(:household).beans.create!(
        name: "Legacy Url Shelf Bag",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 250,
        remaining_grams: 172,
        opened_on: nil
      )
      bean.update_column(:purchase_url, "javascript:alert('bean')")

      bean.open_bag!

      bean.reload
      assert_equal "open", bean.bag_status
      assert_equal Date.new(2026, 6, 13), bean.opened_on
      assert_equal 172.to_d, bean.remaining_grams
      assert_equal "javascript:alert('bean')", bean.purchase_url
    end
  end

  test "origin fallback prefers country region then continent" do
    bean = Bean.new(origin: "Legacy Origin", country: "Colombia", region: "Huila", continent: "South America")
    assert_equal "Colombia", bean.origin_display_value

    bean.country = ""
    assert_equal "Huila", bean.origin_display_value

    bean.region = ""
    assert_equal "South America", bean.origin_display_value

    bean.continent = ""
    assert_equal "Legacy Origin", bean.origin_display_value
  end

  test "private bean urls normalize valid http and https values" do
    bean = workspaces(:household).beans.build(
      name: "Two Website Bag",
      bag_size_grams: 250,
      purchase_url: " https://shop.example/beans ",
      coffee_origin_url: " http://origin.example/coffee "
    )

    assert_predicate bean, :valid?
    assert_equal "https://shop.example/beans", bean.purchase_url
    assert_equal "http://origin.example/coffee", bean.coffee_origin_url

    bean.purchase_url = " "
    bean.coffee_origin_url = ""
    assert_predicate bean, :valid?
    assert_nil bean.purchase_url
    assert_nil bean.coffee_origin_url
  end

  test "safe purchase url strips and drops invalid urls" do
    assert_equal "https://example.com/beans", Bean.safe_purchase_url(" https://example.com/beans ")
    assert_equal "http://example.com/beans", Bean.safe_purchase_url("http://example.com/beans")
    assert_nil Bean.safe_purchase_url("javascript:alert(1)")
    assert_nil Bean.safe_purchase_url("example.com/path")
    assert_nil Bean.safe_purchase_url("https:///path")
  end

  test "safe http url strips valid values and drops unsafe values" do
    assert_equal "https://example.com/beans", Bean.safe_http_url(" https://example.com/beans ")
    assert_equal "http://example.com/beans", Bean.safe_http_url("http://example.com/beans")
    assert Bean.valid_http_url?("https://example.com/beans")
    assert Bean.valid_http_url?("http://example.com/beans")

    [ nil, "", " ", "javascript:alert(1)", "data:text/html,x", "example.com/path", "https:///path" ].each do |url|
      assert_nil Bean.safe_http_url(url), "expected #{url.inspect} to be dropped"
      assert_not Bean.valid_http_url?(url), "expected #{url.inspect} to be invalid"
    end
  end

  test "unrelated bean edits tolerate unchanged legacy invalid purchase url" do
    bean = beans(:open_household)
    bean.update_column(:purchase_url, "javascript:alert('bean')")

    assert_nothing_raised do
      bean.update!(notes: "Updated notes without touching purchase URL")
    end

    assert_equal "javascript:alert('bean')", bean.reload.purchase_url
    assert_equal "Updated notes without touching purchase URL", bean.notes
  end

  test "private bean urls reject unsafe schemeless and hostless values" do
    bean = workspaces(:household).beans.build(
      name: "Unsafe Website Bag",
      bag_size_grams: 250
    )

    %i[purchase_url coffee_origin_url].each do |attribute|
      [ "javascript:alert(1)", "data:text/html,x", "example.com/path", "https:///path" ].each do |url|
        bean.public_send("#{attribute}=", url)

        assert_not_predicate bean, :valid?, "#{attribute}=#{url.inspect} should be invalid"
        assert_includes bean.errors[attribute], "must be an HTTP or HTTPS URL"
      end
    end
  end

  test "cost per shot averages bean in across espresso brews only" do
    bean = workspaces(:household).beans.create!(
      name: "Espresso Cost Bag",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current,
      purchase_price_cents: 1000
    )
    [ 18, 20 ].each do |bean_in|
      bean.brews.create!(
        workspace: bean.workspace,
        user: users(:one),
        method: "espresso",
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        bean_weight_grams: bean_in,
        ground_weight_grams: bean_in - 1,
        dose_grams: bean_in - 2,
        beverage_grams: 45
      )
    end
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      method: "quick_drip",
      grinder: equipment(:household_grinder),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 60
    )

    assert_equal 40.to_d, bean.cost_per_kg
    assert_equal 10.to_d, bean.cost_per_package
    assert_equal 19.to_d, bean.average_espresso_bean_weight_grams
    assert_equal 0.76.to_d, bean.cost_per_shot
  end

  test "cost per shot charges full bean in without double counting ground out or dose" do
    bean = workspaces(:household).beans.create!(
      name: "Waste Cost Bag",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current,
      purchase_price_cents: 1000
    )
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      method: "espresso",
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: 20,
      ground_weight_grams: 19,
      dose_grams: 17,
      beverage_grams: 42
    )

    assert_equal 20.to_d, bean.shot_weight_for_cost
    assert_equal 0.8.to_d, bean.cost_per_shot
  end

  test "cost per shot uses eighteen grams before espresso and ignores manual corrections" do
    bean = workspaces(:household).beans.create!(
      name: "Fresh Cost Bag",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current,
      purchase_price_cents: 1000
    )
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      method: "quick_drip",
      grinder: equipment(:household_grinder),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 60
    )

    assert_nil bean.average_espresso_bean_weight_grams
    assert_equal 18.to_d, bean.shot_weight_for_cost
    assert_equal 0.72.to_d, bean.cost_per_shot

    adjustment = bean.inventory_adjustments.new(
      workspace: bean.workspace,
      user: users(:one),
      reason: "manual",
      delta_grams: -25,
      note: "Count correction"
    )
    assert adjustment.save_with_inventory_update

    assert_nil bean.reload.average_espresso_bean_weight_grams
    assert_equal 18.to_d, bean.shot_weight_for_cost
    assert_equal 0.72.to_d, bean.cost_per_shot

    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      method: "espresso",
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: 20,
      ground_weight_grams: 19,
      dose_grams: 17,
      beverage_grams: 42
    )

    assert_equal 20.to_d, bean.reload.shot_weight_for_cost
    assert_equal 0.8.to_d, bean.cost_per_shot
  end

  test "display name for collection adds opened date only for duplicate open bags" do
    workspace = workspaces(:household)
    first = beans(:open_household)
    second = workspace.beans.create!(
      name: first.name,
      roaster_name: first.roaster_name,
      bag_size_grams: 250,
      opened_on: Date.new(2026, 5, 20)
    )

    beans = [ first, second, beans(:second_open_household) ]

    assert_equal "Good Coffee - House Blend (opened 10.05.2026)", first.display_name_for_collection(beans)
    assert_equal "Good Coffee - House Blend (opened 20.05.2026)", second.display_name_for_collection(beans)
    assert_equal "North Star - Morning Lot", beans(:second_open_household).display_name_for_collection(beans)
  end

  test "destroys bean with brews and inventory history" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    manual_adjustment = bean.inventory_adjustments.create!(
      workspace: bean.workspace,
      user: users(:one),
      delta_grams: 25,
      reason: "manual",
      note: "Found extra beans."
    )
    other_workspace_brew = brews(:other_workspace_brew)

    assert_difference -> { Bean.count }, -1 do
      assert_difference -> { Brew.count }, -1 do
        assert_difference -> { InventoryAdjustment.count }, -2 do
          bean.destroy_with_history!
        end
      end
    end

    assert_nil Bean.find_by(id: bean.id)
    assert_nil Brew.find_by(id: brew.id)
    assert_nil InventoryAdjustment.find_by(id: manual_adjustment.id)
    assert_predicate Brew.find_by(id: other_workspace_brew.id), :present?
  end
end
