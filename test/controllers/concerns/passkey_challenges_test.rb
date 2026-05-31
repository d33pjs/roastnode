require "test_helper"

class PasskeyChallengesTest < ActiveSupport::TestCase
  class ControllerDouble
    include PasskeyChallenges

    attr_reader :session

    def initialize
      @session = {}
    end
  end

  setup do
    @controller = ControllerDouble.new
  end

  test "challenge consumption is single use" do
    @controller.send(:store_passkey_challenge, :registration, "single-use-challenge")

    assert_equal "single-use-challenge", @controller.send(:consume_passkey_challenge, :registration)
    assert_nil @controller.send(:consume_passkey_challenge, :registration)
  end

  test "expired challenges are not returned" do
    travel_to Time.zone.local(2026, 5, 31, 12, 0, 0) do
      @controller.send(:store_passkey_challenge, :login, "expired-challenge")
    end

    travel_to Time.zone.local(2026, 5, 31, 12, 11, 0) do
      assert_nil @controller.send(:consume_passkey_challenge, :login)
    end
  end

  test "challenge consumption enforces user scope" do
    @controller.send(:store_passkey_challenge, :second_factor, "scoped-challenge", user_id: users(:one).id)

    assert_nil @controller.send(:consume_passkey_challenge, :second_factor, user_id: users(:two).id)
  end

  test "pending passkey user expires and clears session keys" do
    travel_to Time.zone.local(2026, 5, 31, 12, 0, 0) do
      @controller.send(:store_pending_passkey_user, users(:one))
    end

    travel_to Time.zone.local(2026, 5, 31, 12, 11, 0) do
      assert_nil @controller.send(:pending_passkey_user)
      assert_nil @controller.session[:pending_passkey_user_id]
      assert_nil @controller.session[:pending_passkey_user_created_at]
    end
  end

  test "pending passkey user clears when user row no longer exists" do
    @controller.session[:pending_passkey_user_id] = User.maximum(:id).to_i + 100
    @controller.session[:pending_passkey_user_created_at] = Time.current.iso8601

    assert_nil @controller.send(:pending_passkey_user)
    assert_nil @controller.session[:pending_passkey_user_id]
    assert_nil @controller.session[:pending_passkey_user_created_at]
  end
end
