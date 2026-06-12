require "test_helper"

class PublicBeanShareViewTest < ActiveSupport::TestCase
  test "recent scope returns newest views first" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )
    older = share.public_bean_share_views.create!(
      workspace: share.workspace,
      ip_address: "198.51.100.10",
      viewed_at: 2.days.ago
    )
    newer = share.public_bean_share_views.create!(
      workspace: share.workspace,
      ip_address: "198.51.100.11",
      viewed_at: 1.hour.ago
    )

    assert_equal [ newer, older ], share.public_bean_share_views.recent.to_a
  end

  test "retains only latest 100 views for a share" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    101.times do |index|
      share.public_bean_share_views.create!(
        workspace: share.workspace,
        ip_address: "198.51.100.#{index}",
        viewed_at: index.minutes.ago
      )
    end

    assert_equal 100, share.public_bean_share_views.count
  end
end
