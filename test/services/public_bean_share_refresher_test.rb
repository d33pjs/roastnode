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

  test "refresh preserves a cleared title for public fallback rendering" do
    bean = beans(:open_household)
    share = create_share(bean)
    share.update!(title: "", snapshot: share.snapshot.merge("title" => ""))

    PublicBeanShareRefresher.refresh(share)

    assert_equal "", share.reload.title
    assert_equal "", share.snapshot.fetch("title")
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

  test "shares_for bean retains only its directly linked public bean share" do
    bean = beans(:open_household)
    first_share = create_share(bean)
    second_share = create_share(beans(:second_open_household))
    other_workspace_share = create_share(beans(:other_workspace_open), user: users(:two))

    assert_equal [ first_share.id ],
      PublicBeanShareRefresher.shares_for(bean).pluck(:id).sort
    assert_not_includes PublicBeanShareRefresher.shares_for(bean), second_share
    assert_not_includes PublicBeanShareRefresher.shares_for(bean), other_workspace_share
  end

  test "shares_for brew retains only its directly linked public bean share" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:)
    first_share = create_share(bean)
    second_share = create_share(beans(:second_open_household))
    other_workspace_share = create_share(beans(:other_workspace_open), user: users(:two))

    assert_equal [ first_share.id ],
      PublicBeanShareRefresher.shares_for(brew).pluck(:id).sort
    assert_not_includes PublicBeanShareRefresher.shares_for(brew), second_share
    assert_not_includes PublicBeanShareRefresher.shares_for(brew), other_workspace_share
  end

  test "refresh_comparisons_for brew refreshes peer shares in the same workspace only" do
    brew = brews(:morning_espresso)
    peer_bean = beans(:second_open_household)
    peer_bean.workspace.brews.create!(
      user: users(:one),
      bean: peer_bean,
      method: "espresso",
      bean_weight_grams: 18,
      rating: 5,
      channeling: true
    )
    create_share(brew.bean)
    peer_share = create_share(peer_bean)
    other_workspace_share = create_share(beans(:other_workspace_open), user: users(:two))

    assert_equal 2, peer_share.snapshot.dig("comparisons", "channeling", "rank")
    other_workspace_share.update_columns(snapshot: other_workspace_share.snapshot.merge("comparison_marker" => "untouched"))
    brew.update!(rating: 5, channeling: true)

    PublicBeanShareRefresher.refresh_comparisons_for(brew)

    assert_equal 1, peer_share.reload.snapshot.dig("comparisons", "channeling", "rank")
    assert_equal "untouched", other_workspace_share.reload.snapshot["comparison_marker"]
  end

  test "shares_for user finds bean shares containing that users brews" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, user: users(:two))
    share = create_share(bean)

    assert_includes PublicBeanShareRefresher.shares_for(users(:two)), share
  end

  test "shares_for user finds recipient-only bean shares distinctly" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, user: users(:one), recipient_kind: "household_member", recipient_user: users(:two))
    share = create_share(bean)

    assert_equal [ share.id ], PublicBeanShareRefresher.shares_for(users(:two)).pluck(:id)
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
    def create_share(bean, selected_photo_attachment_ids: [], user: users(:one))
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: user,
        updated_by: user,
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
