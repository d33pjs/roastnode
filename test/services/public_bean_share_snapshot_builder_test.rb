require "test_helper"

class PublicBeanShareSnapshotBuilderTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "builds a public-safe bean snapshot with all brew methods" do
    bean = beans(:open_household)
    bean.update!(
      public_note: "Public bean note.",
      notes: "Private bean note.",
      purchase_source: "Private cellar source.",
      purchase_price_cents: 1290,
      origin: "Colombia",
      continent: "South America",
      country_of_manufacturer: "Germany",
      manufacturer: "Calendar Coffee",
      process: "Washed",
      tasting_notes: "Berry and caramel"
    )
    bean.record_links.create!(
      workspace: bean.workspace,
      label: "Buy beans",
      url: "https://example.com/beans",
      kind: "affiliate",
      visibility: "public",
      position: 10
    )
    bean.record_links.create!(
      workspace: bean.workspace,
      label: "Private receipt",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private",
      position: 20
    )
    espresso = brews(:morning_espresso)
    espresso.update!(
      bean:,
      notes: "Private espresso note",
      public_note: "Public espresso note",
      bean_weight_grams: 18,
      ground_weight_grams: 17.2,
      dose_grams: 17.2,
      beverage_grams: 42,
      total_time_seconds: 28,
      rating: 5,
      channeling: true,
      taste_balance: "neutral",
      grind_setting: "2.3",
      served_for_guest: true,
      guest_name: "Anna",
      cup_style: "Latte"
    )
    quick_drip = bean.workspace.brews.create!(
      user: users(:two),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      bean_weight_grams: 30,
      beverage_grams: 720,
      total_time_seconds: 300,
      rating: 4,
      taste_balance: "neutral",
      notes: "Private batch note",
      public_note: "Public batch note"
    )
    bean_photo = attach_photo_with_filename(bean, "private-bag-name.jpg")
    brew_photo = attach_photo(espresso)
    avatar = attach_named_photo(users(:two), :avatar, filename: "avatar.jpg")
    logo = attach_named_photo(bean.workspace, :logo, filename: "house.jpg")

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: [ bean_photo.id, brew_photo.id ]
    ).call

    assert_equal "Shared bean", snapshot.fetch("title")
    assert_equal "Public bean note.", snapshot.dig("bean", "public_note")
    assert_equal "Colombia", snapshot.dig("bean", "origin")
    assert_equal "South America", snapshot.dig("bean", "continent")
    assert_equal "Germany", snapshot.dig("bean", "country_of_manufacturer")
    assert_equal "Calendar Coffee", snapshot.dig("bean", "manufacturer")
    assert_equal "Washed", snapshot.dig("bean", "process")
    assert_equal "Berry and caramel", snapshot.dig("bean", "tasting_notes")
    assert_equal 2, snapshot.dig("stats", "brew_count")
    assert_equal "48.0", snapshot.dig("stats", "consumed_grams")
    assert_equal "0.8", snapshot.dig("stats", "dead_grams")
    assert_equal 1, snapshot.dig("stats", "channeling_brew_count")
    assert_equal 100, snapshot.dig("stats", "channeling_percent")
    assert_equal({ "4" => 1, "5" => 1 }, snapshot.dig("distributions", "rating"))
    assert_equal({ "neutral" => 2 }, snapshot.dig("distributions", "taste_balance"))
    assert_equal({ "2.3" => 1 }, snapshot.dig("distributions", "grind_setting"))
    assert_equal 2, snapshot.fetch("brews").size
    assert_equal %w[quick_drip espresso], snapshot.fetch("brews").map { |brew| brew.fetch("method") }
    quick_drip_timeline_row = snapshot.dig("timeline", "brews").find { |brew| brew.fetch("method") == "quick_drip" }
    assert_equal users(:two).display_label, quick_drip_timeline_row.dig("user", "display_label")
    assert_equal avatar.id, quick_drip_timeline_row.dig("user", "avatar_attachment_id")
    assert_equal 4, quick_drip_timeline_row.fetch("rating")
    quick_drip_row = snapshot.fetch("brews").find { |brew| brew.fetch("method") == "quick_drip" }
    assert_equal "6.0", quick_drip_row.fetch("machine_cups")
    assert_equal "6.0", quick_drip_row.fetch("coffee_spoons")
    assert_equal "5.0", quick_drip_row.fetch("grams_per_coffee_spoon")
    assert_equal "measured", quick_drip_row.fetch("coffee_amount_source")
    %w[
      channeling
      retention_marker
      dose_grams
      ground_weight_grams
      brew_temperature_celsius
      preinfusion_seconds
      first_drip_seconds
    ].each do |key|
      assert_not quick_drip_row.key?(key), "expected Quick Drip row to omit #{key}"
    end
    assert_includes snapshot.to_json, "Public espresso note"
    assert_includes snapshot.to_json, "Public batch note"
    assert_includes snapshot.to_json, "Buy beans"
    assert_includes snapshot.to_json, avatar.id.to_s
    assert_includes snapshot.to_json, logo.id.to_s
    assert_not_includes snapshot.to_json, "Private bean note"
    assert_not_includes snapshot.to_json, "Private cellar source"
    assert_not_includes snapshot.to_json, "Private receipt"
    assert_not_includes snapshot.to_json, "Private espresso note"
    assert_not_includes snapshot.to_json, "Private batch note"
    assert_not_includes snapshot.to_json, "Anna"
    assert_not_includes snapshot.to_json, "Latte"
    assert_not_includes snapshot.to_json, "served_for_guest"
    assert_not_includes snapshot.to_json, "guest_name"
    assert_not_includes snapshot.to_json, "cup_style"
    assert_not_includes snapshot.to_json, "one@example.com"
    assert_not_includes snapshot.to_json, "private-bag-name.jpg"
    assert_includes collect_attachment_ids(snapshot), bean_photo.id
    assert_not_includes collect_attachment_ids(snapshot), brew_photo.id
    assert_equal [ avatar.id, bean_photo.id, logo.id ].sort,
      snapshot.fetch("public_media").map { |media| media.fetch("attachment_id") }.sort
    assert_no_internal_ids(snapshot)
  end

  test "public status collapses used up to finished" do
    bean = beans(:open_household)
    bean.update!(remaining_grams: 0)

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "finished", snapshot.dig("bean", "public_status")
  end

  test "preserves an intentionally blank share title for public fallback rendering" do
    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean: beans(:open_household),
      title: "",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "", snapshot.fetch("title")
  end

  test "includes workspace comparison ranks without peer bean details" do
    bean = beans(:open_household)
    comparison_bean = beans(:second_open_household)
    comparison_bean.workspace.brews.create!(
      user: users(:one),
      bean: comparison_bean,
      method: "espresso",
      bean_weight_grams: 18,
      rating: 5,
      channeling: true
    )

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: []
    ).call

    assert_equal({ "rank" => 2, "eligible_count" => 2 }, snapshot.dig("comparisons", "average_rating"))
    assert_equal({ "rank" => 1, "eligible_count" => 2 }, snapshot.dig("comparisons", "channeling"))
    assert_not_includes snapshot.to_json, comparison_bean.name
    assert_no_internal_ids(snapshot)
  end

  test "counts leftover remaining beans as dead grams when bag is finished" do
    bean = beans(:open_household)
    bean.update!(
      finished_at: Time.zone.parse("2026-05-28 12:00:00"),
      remaining_grams: 12.5
    )

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "finished", snapshot.dig("bean", "public_status")
    assert_equal "12.5", snapshot.dig("stats", "dead_grams")
  end

  test "archives render as finished at the archive time and count leftover beans as dead grams" do
    bean = beans(:open_household)
    archived_at = Time.zone.parse("2026-05-29 13:45:00")
    bean.update!(remaining_grams: 12.5)
    bean.update_columns(archived_at:, finished_at: nil)

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Archived bean",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "finished", snapshot.dig("bean", "public_status")
    assert_equal archived_at.utc.iso8601, snapshot.dig("timeline", "finished_at")
    assert_equal archived_at.utc.iso8601, snapshot.dig("timeline", "end_at")
    assert_equal "12.5", snapshot.dig("stats", "dead_grams")
  end

  test "open bag duration runs through today when its latest brew predates today" do
    travel_to Time.zone.local(2026, 5, 26, 12) do
      bean = beans(:open_household)
      bean.brews.first.update!(occurred_at: Time.zone.local(2026, 5, 20, 9))

      snapshot = PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: "Shared bean",
        selected_photo_attachment_ids: []
      ).call

      assert_equal 16, snapshot.dig("stats", "open_duration_days")
    end
  end

  test "archived bag duration stops at its archived date" do
    travel_to Time.zone.local(2026, 6, 1, 12) do
      bean = beans(:open_household)
      bean.update_columns(archived_at: Time.zone.local(2026, 5, 21, 9), finished_at: nil)

      snapshot = PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: "Archived bean",
        selected_photo_attachment_ids: []
      ).call

      assert_equal 11, snapshot.dig("stats", "open_duration_days")
    end
  end

  test "includes enabled public brew share links for public bean brew rows" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:)
    public_brew_share = brew.create_public_brew_share!(
      workspace: bean.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true,
      title: "Shared shot",
      selected_photo_attachment_ids: [],
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Shared shot",
        selected_photo_attachment_ids: []
      ).call
    )

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: []
    ).call

    brew_row = snapshot.fetch("brews").find { |row| row.fetch("method") == "espresso" }
    assert_equal public_brew_share.token, brew_row.dig("public_share", "token")
    assert_equal "Shared shot", brew_row.dig("public_share", "title")
    assert_no_internal_ids(snapshot)
  end

  test "omits disabled public brew share links from public bean brew rows" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:)
    brew.create_public_brew_share!(
      workspace: bean.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: false,
      title: "Disabled shot",
      selected_photo_attachment_ids: [],
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Disabled shot",
        selected_photo_attachment_ids: []
      ).call
    )

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: []
    ).call

    brew_row = snapshot.fetch("brews").find { |row| row.fetch("method") == "espresso" }
    assert_nil brew_row["public_share"]
  end

  private
    def attach_photo_with_filename(record, filename)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename:, content_type: "image/jpeg")
      end
      record.photos.attachments.last
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

    def assert_no_internal_ids(value)
      case value
      when Hash
        value.each do |key, nested|
          assert key.to_s.end_with?("attachment_id") || !key.to_s.end_with?("id"),
            "expected #{key.inspect} to stay out of the public snapshot"
          assert_no_internal_ids(nested)
        end
      when Array
        value.each { |nested| assert_no_internal_ids(nested) }
      end
    end
end
