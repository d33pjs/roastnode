require "test_helper"

class PublicBrewShareRefresherTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "refresh_for bean updates all affected public shares with new public link" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew)

    brew.bean.record_links.create!(
      workspace: brew.workspace,
      label: "Buy refreshed beans",
      url: "https://example.test/refreshed-beans",
      kind: "buy",
      visibility: "public"
    )

    PublicBrewShareRefresher.refresh_for(brew.bean)

    links = share.reload.snapshot.dig("bean", "links")
    assert_includes links.map { |link| link.fetch("label") }, "Buy refreshed beans"
  end

  test "refresh_for equipment updates grinder and machine shares without leaking private links" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew)
    brew.grinder.record_links.create!(
      workspace: brew.workspace,
      label: "Public burr notes",
      url: "https://example.test/grinder",
      kind: "info",
      visibility: "public"
    )
    brew.grinder.record_links.create!(
      workspace: brew.workspace,
      label: "Private receipt",
      url: "https://example.test/private-grinder",
      kind: "info",
      visibility: "private"
    )

    PublicBrewShareRefresher.refresh_for(brew.grinder)

    snapshot_json = share.reload.snapshot.to_json
    assert_includes snapshot_json, "Public burr notes"
    assert_not_includes snapshot_json, "Private receipt"
  end

  test "refresh filters removed selected photos out of public media allowlist" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew.bean)
    share = create_share_for(brew, selected_photo_attachment_ids: [ photo.id ])
    assert_includes share.public_attachment_ids, photo.id

    photo.destroy!
    PublicBrewShareRefresher.refresh(share)

    share.reload
    assert_not_includes share.selected_photo_attachment_ids, photo.id
    assert_not_includes share.public_attachment_ids, photo.id
  end

  test "refresh shortens legacy generated title" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew, title: PublicBrewShare.legacy_default_title_for(brew))

    PublicBrewShareRefresher.refresh(share)

    share.reload
    assert_equal PublicBrewShare.default_title_for(brew), share.title
    assert_equal PublicBrewShare.default_title_for(brew), share.snapshot.fetch("title")
  end

  test "refresh preserves custom title" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew, title: "Shared morning shot")

    PublicBrewShareRefresher.refresh(share)

    share.reload
    assert_equal "Shared morning shot", share.title
    assert_equal "Shared morning shot", share.snapshot.fetch("title")
  end

  test "refresh replaces the public recipient projection after serving changes" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew)
    assert_equal({ "kind" => "self" }, share.snapshot.dig("brew", "recipient"))

    users(:two).update!(display_name: "Petra")
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    PublicBrewShareRefresher.refresh_for(brew)

    assert_equal(
      { "kind" => "household_member", "display_label" => "Petra" },
      share.reload.snapshot.dig("brew", "recipient")
    )

    brew.update!(recipient_kind: "guest", recipient_name: "Secret Anna")
    PublicBrewShareRefresher.refresh_for(brew)

    snapshot = share.reload.snapshot
    assert_equal({ "kind" => "guest" }, snapshot.dig("brew", "recipient"))
    assert_no_match(/Secret Anna|recipient_name|guest_name|served_for_guest/, snapshot.to_json)
  end

  test "refresh updates selected hero primaries and omits an unselected new primary" do
    brew = brews(:morning_espresso)
    first_bean = attach_photo(brew.bean)
    second_bean = attach_photo(brew.bean)
    first_brew = attach_photo(brew)
    second_brew = attach_photo(brew)
    brew.bean.set_primary_photo!(first_bean)
    brew.set_primary_photo!(first_brew)
    share = create_share_for(
      brew,
      selected_photo_attachment_ids: [ first_bean.id, second_bean.id, first_brew.id ]
    )
    assert_equal first_bean.id, share.snapshot.dig("hero", "bean_photo_attachment_id")
    assert_equal first_brew.id, share.snapshot.dig("hero", "brew_photo_attachment_id")

    brew.bean.set_primary_photo!(second_bean)
    brew.set_primary_photo!(second_brew)
    PublicBrewShareRefresher.refresh_for(brew)

    hero = share.reload.snapshot.fetch("hero")
    assert_equal second_bean.id, hero.fetch("bean_photo_attachment_id")
    assert_not hero.key?("brew_photo_attachment_id")
    assert_not_includes share.selected_photo_attachment_ids, second_brew.id
  end

  private
    def create_share_for(brew, title: "Shared shot", selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title:,
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title:,
          selected_photo_attachment_ids:
        ).call
      )
    end
end
