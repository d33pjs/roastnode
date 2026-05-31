require "test_helper"

class Passkeys::RegistrationTest < ActiveSupport::TestCase
  test "persists verified credential with user verification required" do
    user = users(:one)
    credential = FakeCreatedCredential.new(
      id: "credential-registration-test",
      public_key: "public-key-registration-test",
      sign_count: 1
    )

    stub_webauthn_credential(:from_create, credential) do
      passkey = Passkeys::Registration.new(
        user:,
        challenge: "registration-challenge",
        credential_params: { "id" => credential.id },
        nickname: "Security Key"
      ).save!

      assert_equal user, passkey.user
      assert_equal "credential-registration-test", passkey.external_id
      assert_equal "public-key-registration-test", passkey.public_key
      assert_equal 1, passkey.sign_count
      assert_equal "Security Key", passkey.nickname
    end
  end
end
