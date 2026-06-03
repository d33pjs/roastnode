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

  private
    def create_share_for(brew, selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
