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
    assert_includes bean.errors[:rating], "must be less than or equal to 5"
  end

  test "can close and reopen a bean bag" do
    bean = beans(:archived_household)

    bean.reopen!
    assert_nil bean.archived_at
    assert_equal bean.bag_size_grams, bean.remaining_grams

    bean.close!
    assert_not_nil bean.archived_at
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

  test "duplicates a bean as a new open bag with copied photos" do
    bean = beans(:open_household)
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      bean.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
    end
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      bean.photos.attach(io: file, filename: "label.jpg", content_type: "image/jpeg")
    end
    bean.set_primary_photo!(bean.photos.last)

    duplicate = bean.duplicate_for_new_bag!

    assert_not_equal bean.id, duplicate.id
    assert_equal bean.name, duplicate.name
    assert_equal Date.current, duplicate.opened_on
    assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
    assert_nil duplicate.archived_at
    assert_equal bean.roaster_name, duplicate.roaster_name
    assert_equal bean, duplicate.duplicated_from_bean
    assert_equal bean.photos.first.blob, duplicate.photos.first.blob
    assert_equal bean.primary_photo_attachment.blob, duplicate.primary_photo_attachment.blob
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
