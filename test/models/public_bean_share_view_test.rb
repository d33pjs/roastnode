require "test_helper"

class PublicBeanShareViewTest < ActiveSupport::TestCase
  test "recent scope returns newest views first" do
    share = create_share
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
    share = create_share

    101.times do |index|
      share.public_bean_share_views.create!(
        workspace: share.workspace,
        ip_address: "198.51.100.#{index}",
        viewed_at: index.minutes.ago
      )
    end

    assert_equal 101, share.reload.views_count
    assert_equal 100, share.public_bean_share_views.count
  end

  test "defaults workspace from share and viewed at to current time" do
    share = create_share

    travel_to Time.zone.local(2026, 6, 13, 12, 0, 0) do
      view = share.public_bean_share_views.create!(ip_address: "198.51.100.10")

      assert_equal share.workspace, view.workspace
      assert_equal Time.current, view.viewed_at
    end
  end

  test "requires workspace to match share workspace" do
    share = create_share
    view = PublicBeanShareView.new(
      public_bean_share: share,
      workspace: workspaces(:other_household),
      ip_address: "198.51.100.10"
    )

    assert_not view.valid?
    assert_includes view.errors[:workspace], "must match the public bean share workspace"
  end

  test "validates ip address and user agent length" do
    share = create_share
    view = PublicBeanShareView.new(
      public_bean_share: share,
      ip_address: "x" * 256,
      user_agent: "x" * 513
    )

    assert_not view.valid?
    assert_includes view.errors[:ip_address], "is too long (maximum is 255 characters)"
    assert_includes view.errors[:user_agent], "is too long (maximum is 512 characters)"

    view.ip_address = ""
    assert_not view.valid?
    assert_includes view.errors[:ip_address], "can't be blank"
  end

  private
    def create_share
      PublicBeanShare.create!(
        workspace: workspaces(:household),
        bean: beans(:open_household),
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true
      )
    end
end
