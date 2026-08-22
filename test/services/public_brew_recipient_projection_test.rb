require "test_helper"

class PublicBrewRecipientProjectionTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "self projection is exact kind only" do
    brew = brews(:morning_espresso)

    payload = PublicBrewRecipientProjection.new(brew:).call

    assert_equal({ "kind" => "self" }, payload)
    assert_no_match(/recipient_name|recipient_user|avatar|email/i, payload.to_json)
  end

  test "guest projection is exact kind only whether named or unnamed" do
    brew = brews(:morning_espresso)

    [ "Secret Anna", nil ].each do |name|
      brew.update!(recipient_kind: "guest", recipient_name: name)

      payload = PublicBrewRecipientProjection.new(brew:).call

      assert_equal({ "kind" => "guest" }, payload)
      assert_no_match(/Secret Anna|recipient_name|avatar|email/i, payload.to_json)
    end
  end

  test "current household recipient projects the safe label and integer avatar attachment id" do
    brew = household_recipient_brew
    avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")

    payload = PublicBrewRecipientProjection.new(brew:).call

    assert_equal(
      {
        "kind" => "household_member",
        "display_label" => users(:two).display_label,
        "avatar_attachment_id" => avatar.id
      },
      payload
    )
    assert_instance_of Integer, payload.fetch("avatar_attachment_id")
    assert_no_match(/two@example.com|petra\.jpg|blob|signed|media/i, payload.to_json)
  end

  test "current household recipient without an avatar projects the label only" do
    payload = PublicBrewRecipientProjection.new(brew: household_recipient_brew).call

    assert_equal(
      { "kind" => "household_member", "display_label" => users(:two).display_label },
      payload
    )
  end

  test "blank household display name never falls back to email" do
    users(:two).update!(display_name: nil, email_address: "private-recipient@example.com")

    payload = PublicBrewRecipientProjection.new(brew: household_recipient_brew).call

    assert_equal(
      { "kind" => "household_member", "display_label" => User::UNKNOWN_DISPLAY_LABEL },
      payload
    )
    assert_no_match(/private-recipient@example.com/, payload.to_json)
  end

  test "former household recipient keeps the label but suppresses a warmed avatar" do
    brew = household_recipient_brew
    attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
    brew.recipient_user
    brew.workspace.memberships.to_a
    users(:two).avatar.attachment
    memberships(:member).destroy!

    payload = PublicBrewRecipientProjection.new(brew:).call

    assert_equal(
      { "kind" => "household_member", "display_label" => users(:two).display_label },
      payload
    )
    assert_not payload.key?("avatar_attachment_id")
  end

  test "former household recipient authorizes before reading a reset avatar attachment" do
    brew = household_recipient_brew
    attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
    memberships(:member).destroy!
    users(:two).association(:avatar_attachment).reset
    queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries << payload[:sql] if payload[:name] != "SCHEMA"
    end

    payload = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      PublicBrewRecipientProjection.new(brew:).call
    end

    assert_equal(
      { "kind" => "household_member", "display_label" => users(:two).display_label },
      payload
    )
    assert_empty queries.grep(/active_storage_attachments/i)
  end

  test "viewer household membership authorizes the avatar" do
    memberships(:member).update!(role: "viewer")
    brew = household_recipient_brew
    avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")

    payload = PublicBrewRecipientProjection.new(brew:).call

    assert_equal avatar.id, payload["avatar_attachment_id"]
  end

  test "household kind without a recipient user is identity free" do
    brew = Brew.new(recipient_kind: "household_member")

    assert_equal({ "kind" => "household_member" }, PublicBrewRecipientProjection.new(brew:).call)
  end

  test "missing and unsupported recipient kinds fail closed without identity" do
    [ nil, "unsupported" ].each do |kind|
      brew = Brew.new
      brew.define_singleton_method(:read_attribute_before_type_cast) { |_attribute| kind }
      brew.define_singleton_method(:recipient_user) { raise "unknown kinds must not read identity" }

      assert_equal({ "kind" => "unknown" }, PublicBrewRecipientProjection.new(brew:).call)
    end
  end

  private
    def household_recipient_brew
      brew = brews(:morning_espresso)
      brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
      brew
    end
end
