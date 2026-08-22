require "test_helper"

class PublicBrewShareSnapshotBuilderTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "default title uses bean name without roaster" do
    brew = brews(:morning_espresso)

    snapshot = PublicBrewShareSnapshotBuilder.new(
      brew:,
      title: "",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "Espresso with #{brew.bean.name}", snapshot.fetch("title")
    assert_not_includes snapshot.fetch("title"), brew.bean.roaster_name
  end

  test "builds a public-safe snapshot from selected records" do
    brew = brews(:morning_espresso)
    brew.update!(
      public_note: "Public brew story.",
      notes: "Private brew note.",
      recipient_kind: "guest",
      recipient_name: "Anna",
      cup_style: "Latte"
    )
    brew.bean.update!(public_note: "Public bean note.", notes: "Private bean note.", purchase_source: "Private cellar source.")
    brew.grinder.update!(public_note: "Public grinder note.", notes: "Private grinder note.")
    preparation_tools(:wdt).update!(public_note: "Public WDT note.", notes: "Private WDT note.")
    brew.record_links.create!(
      workspace: brew.workspace,
      label: "Brew writeup",
      url: "https://example.com/brew",
      kind: "info",
      visibility: "public",
      position: 10
    )
    brew.bean.record_links.create!(
      workspace: brew.workspace,
      label: "Buy beans",
      url: "https://example.com/beans",
      kind: "affiliate",
      visibility: "public",
      position: 10
    )
    brew.bean.record_links.create!(
      workspace: brew.workspace,
      label: "Private receipt",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private",
      position: 20
    )

    brew_photo = attach_photo_with_filename(brew, "jens-private-receipt.jpg")
    bean_photo = attach_photo(brew.bean)
    grinder_photo = attach_photo(brew.grinder)
    unselected_photo = attach_photo(brew.bean)
    brew.bean.set_primary_photo!(bean_photo)
    brew.grinder.set_primary_photo!(grinder_photo)

    snapshot = PublicBrewShareSnapshotBuilder.new(
      brew:,
      title: "Shared morning shot",
      selected_photo_attachment_ids: [ brew_photo.id, bean_photo.id, grinder_photo.id ]
    ).call

    assert_equal "Shared morning shot", snapshot.fetch("title")
    assert_equal "Public brew story.", snapshot.fetch("brew").fetch("public_note")
    assert_equal "Public bean note.", snapshot.fetch("bean").fetch("public_note")
    assert_equal "Public grinder note.", snapshot.fetch("equipment").first.fetch("public_note")
    assert_equal "2026-05-02", snapshot.fetch("bean").fetch("purchased_on")
    assert_equal "2026-05-10", snapshot.fetch("bean").fetch("opened_on")
    assert_equal 1290, snapshot.fetch("bean").fetch("purchase_price_cents")
    assert_includes snapshot.to_json, "Buy beans"
    assert_includes snapshot.to_json, "Brew writeup"
    assert_not_includes snapshot.to_json, "Private brew note"
    assert_not_includes snapshot.to_json, "Private bean note"
    assert_not_includes snapshot.to_json, "Private grinder note"
    assert_not_includes snapshot.to_json, "Private WDT note"
    assert_not_includes snapshot.to_json, "Private receipt"
    assert_not_includes snapshot.to_json, "Private cellar source"
    assert_not_includes snapshot.to_json, "Anna"
    assert_not_includes snapshot.to_json, "Latte"
    assert_not_includes snapshot.to_json, "served_for_guest"
    assert_not_includes snapshot.to_json, "guest_name"
    assert_not_includes snapshot.to_json, "cup_style"
    assert_not_includes snapshot.to_json, "Local roaster"
    assert_not_includes snapshot.to_json, "jens-private-receipt.jpg"
    attachment_ids = collect_attachment_ids(snapshot)
    assert_includes attachment_ids, brew_photo.id
    assert_includes attachment_ids, bean_photo.id
    assert_includes attachment_ids, grinder_photo.id
    assert_not_includes attachment_ids, unselected_photo.id
    assert_no_internal_ids(snapshot)
  end

  test "projects exact public recipient payloads" do
    brew = brews(:morning_espresso)

    assert_equal({ "kind" => "self" }, build_snapshot(brew).dig("brew", "recipient"))

    avatar = attach_named_photo(users(:two), :avatar, filename: "petra-private.jpg")
    users(:two).update!(display_name: "Petra")
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    assert_equal(
      {
        "kind" => "household_member",
        "display_label" => "Petra",
        "avatar_attachment_id" => avatar.id
      },
      build_snapshot(brew).dig("brew", "recipient")
    )

    brew.update!(recipient_kind: "guest", recipient_name: "Secret Anna")
    snapshot = build_snapshot(brew)
    assert_equal({ "kind" => "guest" }, snapshot.dig("brew", "recipient"))
    assert_no_match(/Secret Anna|recipient_name|guest_name|served_for_guest|two@example\.com|petra-private\.jpg/, snapshot.to_json)
  end

  test "hero references include only selected current bean and brew primaries" do
    brew = brews(:morning_espresso)
    bean_primary = attach_photo(brew.bean)
    bean_non_primary = attach_photo(brew.bean)
    brew_primary = attach_photo(brew)
    brew_non_primary = attach_photo(brew)
    brew.bean.set_primary_photo!(bean_primary)
    brew.set_primary_photo!(brew_primary)

    cases = {
      both: [ [ bean_primary.id, brew_primary.id ], {
        "bean_photo_attachment_id" => bean_primary.id,
        "brew_photo_attachment_id" => brew_primary.id
      } ],
      bean_only: [ [ bean_primary.id ], { "bean_photo_attachment_id" => bean_primary.id } ],
      brew_only: [ [ brew_primary.id ], { "brew_photo_attachment_id" => brew_primary.id } ],
      neither: [ [], {} ],
      selected_non_primary: [ [ bean_non_primary.id, brew_non_primary.id ], {} ]
    }

    cases.each do |name, (selected_ids, expected)|
      snapshot = build_snapshot(brew, selected_photo_attachment_ids: selected_ids)
      assert_equal expected, snapshot.fetch("hero"), name.to_s
    end
  end

  private
    def build_snapshot(brew, selected_photo_attachment_ids: [])
      PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Shared shot",
        selected_photo_attachment_ids:
      ).call
    end

    def assert_no_internal_ids(value)
      case value
      when Hash
        value.each do |key, nested|
          assert key.to_s.end_with?("attachment_id") || !key.to_s.end_with?("id"), "expected #{key.inspect} to stay out of the public snapshot"
          assert_no_internal_ids(nested)
        end
      when Array
        value.each { |nested| assert_no_internal_ids(nested) }
      end
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end

    def attach_photo_with_filename(record, filename)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename:, content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end
end
