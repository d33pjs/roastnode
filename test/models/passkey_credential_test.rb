require "test_helper"

class PasskeyCredentialTest < ActiveSupport::TestCase
  test "belongs to a user and requires unique external id" do
    credential = PasskeyCredential.new(
      user: users(:one),
      external_id: "credential-unique-test",
      public_key: "public-key",
      sign_count: 0,
      nickname: "MacBook Touch ID"
    )

    assert credential.valid?
    credential.save!

    duplicate = PasskeyCredential.new(
      user: users(:two),
      external_id: "credential-unique-test",
      public_key: "other-public-key",
      sign_count: 0,
      nickname: "Other device"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "normalizes blank nickname to nil" do
    credential = PasskeyCredential.create!(
      user: users(:one),
      external_id: "credential-blank-nickname",
      public_key: "public-key",
      sign_count: 0,
      nickname: "   "
    )

    assert_nil credential.nickname
  end

  test "display name is nil safe before persistence" do
    credential = PasskeyCredential.new

    assert_equal "Passkey", credential.display_name
  end
end
