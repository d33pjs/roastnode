require "test_helper"
require Rails.root.join("db/migrate/20260821113000_refresh_public_recipient_hero_snapshots")

class RefreshPublicRecipientHeroSnapshotsTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "up rebuilds existing brew and bean shares with current guest recipient and hero state" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Secret Anna")
    bean_photo = attach_photo(brew.bean)
    brew_photo = attach_photo(brew)
    brew.bean.set_primary_photo!(bean_photo)
    brew.set_primary_photo!(brew_photo)
    brew_share = create_public_brew_share(brew, selected_ids: [ bean_photo.id, brew_photo.id ])
    bean_share = create_public_bean_share(brew.bean, selected_ids: [ bean_photo.id ])

    RefreshPublicRecipientHeroSnapshots.new.up

    assert_equal({ "kind" => "guest" }, brew_share.reload.snapshot.dig("brew", "recipient"))
    assert_equal(
      {
        "bean_photo_attachment_id" => bean_photo.id,
        "brew_photo_attachment_id" => brew_photo.id
      },
      brew_share.snapshot.fetch("hero")
    )
    bean_snapshot = bean_share.reload.snapshot
    assert_equal({ "kind" => "guest" }, bean_snapshot.fetch("brews").first.fetch("recipient"))
    assert_equal({ "kind" => "guest" }, bean_snapshot.dig("timeline", "brews").first.fetch("recipient"))
    assert_no_match(/Secret Anna|recipient_name|guest_name|served_for_guest/, brew_share.snapshot.to_json)
    assert_no_match(/Secret Anna|recipient_name|guest_name|served_for_guest/, bean_snapshot.to_json)
  end

  test "up includes current household identity and removes it after membership revocation" do
    recipient = users(:two)
    recipient.update!(display_name: "Petra")
    avatar = attach_named_photo(recipient, :avatar, filename: "private-petra.jpg")
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "household_member", recipient_user: recipient)
    brew_share = create_public_brew_share(brew)
    bean_share = create_public_bean_share(brew.bean)

    RefreshPublicRecipientHeroSnapshots.new.up

    expected_current = {
      "kind" => "household_member",
      "display_label" => "Petra",
      "avatar_attachment_id" => avatar.id
    }
    assert_equal expected_current, brew_share.reload.snapshot.dig("brew", "recipient")
    assert_equal expected_current, bean_share.reload.snapshot.fetch("brews").first.fetch("recipient")

    memberships(:member).destroy!
    RefreshPublicRecipientHeroSnapshots.new.up

    expected_former = { "kind" => "household_member", "display_label" => "Petra" }
    assert_equal expected_former, brew_share.reload.snapshot.dig("brew", "recipient")
    assert_equal expected_former, bean_share.reload.snapshot.fetch("brews").first.fetch("recipient")
    assert_not_includes brew_share.snapshot.fetch("public_media").pluck("attachment_id"), avatar.id
    assert_not_includes bean_share.snapshot.fetch("public_media").pluck("attachment_id"), avatar.id
  end

  test "down preserves already stored safer snapshots" do
    brew = brews(:morning_espresso)
    brew_share = create_public_brew_share(brew)
    bean_share = create_public_bean_share(brew.bean)
    brew_snapshot = { "brew" => { "recipient" => { "kind" => "self" } }, "safer" => true }
    bean_snapshot = { "brews" => [ { "recipient" => { "kind" => "self" } } ], "safer" => true }
    brew_share.update_columns(snapshot: brew_snapshot)
    bean_share.update_columns(snapshot: bean_snapshot)

    RefreshPublicRecipientHeroSnapshots.new.down

    assert_equal brew_snapshot, brew_share.reload.snapshot
    assert_equal bean_snapshot, bean_share.reload.snapshot
  end

  private
    def create_public_brew_share(brew, selected_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids: selected_ids,
        snapshot: { "legacy" => true }
      )
    end

    def create_public_bean_share(bean, selected_ids: [])
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: selected_ids,
        snapshot: { "legacy" => true }
      )
    end
end
