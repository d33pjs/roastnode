require "test_helper"

class PublicBrewShareSnapshotBuilderTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "builds a public-safe snapshot from selected records" do
    brew = brews(:morning_espresso)
    brew.update!(public_note: "Public brew story.", notes: "Private brew note.")
    brew.bean.update!(public_note: "Public bean note.", notes: "Private bean note.")
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

    brew_photo = attach_photo(brew)
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
    assert_equal 1290, snapshot.fetch("bean").fetch("purchase_price_cents")
    assert_includes snapshot.to_json, "Buy beans"
    assert_includes snapshot.to_json, "Brew writeup"
    assert_not_includes snapshot.to_json, "Private brew note"
    assert_not_includes snapshot.to_json, "Private bean note"
    assert_not_includes snapshot.to_json, "Private grinder note"
    assert_not_includes snapshot.to_json, "Private WDT note"
    assert_not_includes snapshot.to_json, "Private receipt"
    attachment_ids = collect_attachment_ids(snapshot)
    assert_includes attachment_ids, brew_photo.id
    assert_includes attachment_ids, bean_photo.id
    assert_includes attachment_ids, grinder_photo.id
    assert_not_includes attachment_ids, unselected_photo.id
  end

  private
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
end
