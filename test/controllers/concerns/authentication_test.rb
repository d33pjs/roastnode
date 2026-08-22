require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "session creation rolls back when sign in emission fails" do
    user = users(:one)

    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "emission failed" }) do
      assert_no_difference -> { user.sessions.count } do
        assert_raises(RuntimeError) do
          post session_path, params: { email_address: user.email_address, password: "password" }
        end
      end
    end

    assert_nil cookies[:session_id]
  end

  test "session deletion rolls back when sign out emission fails" do
    user = users(:one)
    sign_in_as(user)
    session_record = Current.session

    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "emission failed" }) do
      assert_raises(RuntimeError) { delete session_path }
    end

    assert Session.exists?(session_record.id)
  end
end
