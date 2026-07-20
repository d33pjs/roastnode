require "test_helper"

class PublicBeanShareRefresherTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "refreshes shares for bean changes" do
    bean = beans(:open_household)
    share = create_share(bean)

    bean.update!(public_note: "Updated public note")
    PublicBeanShareRefresher.refresh_for(bean)

    assert_equal "Updated public note", share.reload.snapshot.dig("bean", "public_note")
  end

  test "refreshes shares for brew changes" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, public_note: "Old note")
    share = create_share(bean)

    brew.update!(public_note: "New brew note")
    PublicBeanShareRefresher.refresh_for(brew)

    assert_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "New brew note"
  end

  test "shares_for user finds bean shares containing that users brews" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, user: users(:two))
    share = create_share(bean)

    assert_includes PublicBeanShareRefresher.shares_for(users(:two)), share
  end

  test "refresh removes selected photos that no longer belong to bean" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean, selected_photo_attachment_ids: [ photo.id ])

    photo.destroy
    PublicBeanShareRefresher.refresh(share)

    assert_equal [], share.reload.selected_photo_attachment_ids
    assert_equal [], share.snapshot.fetch("photos")
  end

  test "refresh keeps archived opened bean shares enabled and updates the terminal snapshot" do
    bean = beans(:open_household)
    share = create_share(bean)

    bean.archive!
    PublicBeanShareRefresher.refresh(share)

    assert share.reload.enabled?
    assert_equal "finished", share.snapshot.dig("bean", "public_status")
    assert_equal bean.archived_at.utc.iso8601, share.snapshot.dig("timeline", "finished_at")
  end

  test "refresh disables shares when bean no longer has an opened lifecycle" do
    bean = beans(:open_household)
    share = create_share(bean)

    bean.apply_bag_status("stock")
    bean.save!
    PublicBeanShareRefresher.refresh(share)

    assert_not share.reload.enabled?
  end

  test "refreshes shares for equipment changes" do
    bean = beans(:open_household)
    grinder = equipment(:household_grinder)
    machine = equipment(:household_machine)
    brewer = equipment(:household_brewer)
    brews(:morning_espresso).update!(bean:, grinder:, machine:)
    bean.workspace.brews.create!(
      user: users(:two),
      method: "quick_drip",
      bean:,
      brewer:,
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      bean_weight_grams: 30,
      beverage_grams: 720,
      total_time_seconds: 300
    )
    share = create_share(bean)

    grinder.update!(name: "Updated grinder")
    PublicBeanShareRefresher.refresh_for(grinder)
    assert_includes snapshot_equipment_names(share), "Updated grinder"

    machine.update!(name: "Updated machine")
    PublicBeanShareRefresher.refresh_for(machine)
    assert_includes snapshot_equipment_names(share), "Updated machine"

    brewer.update!(name: "Updated brewer")
    PublicBeanShareRefresher.refresh_for(brewer)
    assert_includes snapshot_equipment_names(share), "Updated brewer"
  end

  private
    def create_share(bean, selected_photo_attachment_ids: [])
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end

    def snapshot_equipment_names(share)
      share.reload.snapshot.fetch("brews").flat_map do |brew|
        brew.fetch("equipment", {}).values.map { |equipment| equipment["name"] }
      end
    end
end
