require "test_helper"

class PublicBrewShareViewTest < ActiveSupport::TestCase
  test "records full ip addresses and keeps all time counter after pruning retained rows" do
    share = create_share

    101.times do |index|
      PublicBrewShareView.create!(
        public_brew_share: share,
        ip_address: "203.0.113.#{index % 250}",
        user_agent: "MiniTest/#{index}",
        viewed_at: Time.zone.local(2026, 6, 3, 10, 0, 0) + index.seconds
      )
    end

    share.reload
    assert_equal 101, share.views_count
    assert_equal 100, share.public_brew_share_views.count
    assert_equal "203.0.113.100", share.public_brew_share_views.recent.first.ip_address
    assert_equal share.workspace, share.public_brew_share_views.recent.first.workspace
  end

  private
    def create_share
      brew = brews(:morning_espresso)
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
