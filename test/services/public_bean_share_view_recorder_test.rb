require "test_helper"

class PublicBeanShareViewRecorderTest < ActiveSupport::TestCase
  test "records a public bean share view and increments counter" do
    share = create_share
    request = fake_request(remote_ip: "198.51.100.42", user_agent: "Roastnode test browser")

    travel_to Time.zone.local(2026, 6, 13, 12, 30, 0) do
      assert_difference -> { PublicBeanShareView.count }, 1 do
        assert_difference -> { share.reload.views_count }, 1 do
          PublicBeanShareViewRecorder.new(share:, request:).call
        end
      end

      view = share.public_bean_share_views.last
      assert_equal share.workspace, view.workspace
      assert_equal "198.51.100.42", view.ip_address
      assert_equal "Roastnode test browser", view.user_agent
      assert_equal Time.current, view.viewed_at
    end
  end

  test "truncates overlong remote ip and user agent" do
    share = create_share
    request = fake_request(remote_ip: "1" * 300, user_agent: "Browser " + ("x" * 600))

    assert_nothing_raised do
      PublicBeanShareViewRecorder.new(share:, request:).call
    end

    view = share.public_bean_share_views.last
    assert_equal 255, view.ip_address.length
    assert_equal 512, view.user_agent.length
  end

  private
    FakeRequest = Struct.new(:remote_ip, :user_agent, keyword_init: true)

    def fake_request(remote_ip:, user_agent:)
      FakeRequest.new(remote_ip:, user_agent:)
    end

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
