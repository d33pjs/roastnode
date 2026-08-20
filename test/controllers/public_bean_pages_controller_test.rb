require "test_helper"

class PublicBeanPagesControllerTest < ActionDispatch::IntegrationTest
  include PhotoTestHelper

  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_bean_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without private content" do
    share = create_share(enabled: true)
    share.workspace.update!(buy_me_a_coffee_url: "https://buymeacoffee.com/roastnode")

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-page]"
    assert_select "[data-testid=public-bean-timeline]"
    assert_select "[data-testid=public-bean-journey]"
    assert_select "[data-testid=public-bean-journey-track]"
    assert_select "[data-testid=public-bean-journey-opened]"
    assert_select "[data-testid=public-bean-journey-end][data-status=open]"
    assert_select "[data-testid=public-bean-journey-end-open-icon]"
    assert_select "[data-testid=public-bean-journey-brew][data-method=espresso]", minimum: 1
    assert_select "[data-testid=public-bean-brew-compact-card]", minimum: 1
    assert_select "body", text: /Public bean note/
    assert_select "body", text: /Private bean note/, count: 0
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "enabled share renders public bean metadata details" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot["bean"]["continent"] = "South America"
    snapshot["bean"]["country_of_manufacturer"] = "Germany"
    snapshot["bean"]["manufacturer"] = "Calendar Coffee"
    share.update!(snapshot:)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-details]", text: /South America/
    assert_select "[data-testid=public-bean-details]", text: /Germany/
    assert_select "[data-testid=public-bean-details]", text: /Calendar Coffee/
  end

  test "public page renders first and second place comparison badges" do
    share = create_share(enabled: true)
    set_comparisons(
      share,
      "average_rating" => { "rank" => 1, "eligible_count" => 8 },
      "channeling" => { "rank" => 2, "eligible_count" => 6 }
    )

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-average-rating-comparison-badge][aria-label='TOP 1 OF 8 BEANS'].border-amber-300"
    assert_select "[data-testid=public-bean-average-rating-comparison-badge] svg[data-rank-icon=trophy][aria-hidden=true][focusable=false]"
    assert_select "[data-testid=public-bean-channeling-comparison-badge][aria-label='TOP 2 OF 6 BEANS'].border-slate-300"
    assert_select "[data-testid=public-bean-channeling-comparison-badge] svg[data-rank-icon=medal][aria-hidden=true][focusable=false]"
  end

  test "public page renders a bronze medal for third and no icon after the podium" do
    share = create_share(enabled: true)
    set_comparisons(
      share,
      "average_rating" => { "rank" => 3, "eligible_count" => 9 },
      "channeling" => { "rank" => 4, "eligible_count" => 7 }
    )

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-average-rating-comparison-badge][aria-label='TOP 3 OF 9 BEANS'].border-orange-300"
    assert_select "[data-testid=public-bean-average-rating-comparison-badge] svg[data-rank-icon=medal]"
    assert_select "[data-testid=public-bean-channeling-comparison-badge][aria-label='TOP 4 OF 7 BEANS'].border-rn-line"
    assert_select "[data-testid=public-bean-channeling-comparison-badge] svg", count: 0
  end

  test "legacy public bean snapshots render without comparison badges" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot.delete("comparisons")
    share.update!(snapshot:)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid$='-comparison-badge']", count: 0
  end

  test "timeline clusters dense brews without rendering callout cards" do
    avatar = attach_named_photo(users(:one), :avatar, filename: "timeline-avatar.jpg")
    bean = beans(:open_household)
    bean.update!(
      opened_on: Date.new(2026, 1, 12),
      finished_at: Time.zone.parse("2026-05-28 12:00:00"),
      remaining_grams: 0
    )
    brews(:morning_espresso).update!(
      bean:,
      occurred_at: Time.zone.parse("2026-01-13 08:00:00"),
      rating: 4
    )
    3.times do |index|
      bean.workspace.brews.create!(
        user: users(:one),
        method: "espresso",
        bean:,
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.parse("2026-01-13 08:0#{index + 1}:00"),
        bean_weight_grams: 18,
        ground_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 40,
        rating: index + 1,
        taste_balance: "neutral"
      )
    end
    bean.workspace.brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      occurred_at: Time.zone.parse("2026-05-10 09:00:00"),
      machine_cups: 6,
      bean_weight_grams: 30,
      rating: 5,
      taste_balance: "neutral"
    )
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-journey-callout]", count: 0
    assert_select "[data-testid=public-bean-journey-cluster][data-count='4']", text: /4/
    assert_select "[data-testid=public-bean-journey-cluster-rating]", 4
    assert_select "[data-testid=public-bean-journey-avatar]", count: 0
    assert_select "[data-testid=public-bean-journey-marker-label][data-side][data-lane]"
    assert_select "[data-testid=public-bean-journey-marker-connector][data-side][data-lane]"
    assert_select "[data-testid=public-bean-journey-brew-count-dot]", minimum: 1
    assert_equal 1, response.body.scan("January 12, 2026").size
    assert_equal 1, response.body.scan("May 28, 2026").size
    assert share.public_media_handle_for(avatar.id).present?, "expected avatar to remain public media even when not rendered on the timeline"
  end

  test "public page header shows roastnode brand and household identity" do
    logo = attach_named_photo(beans(:open_household).workspace, :logo, filename: "household-logo.jpg")
    share = create_share(enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-roastnode-brand] img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "[data-testid=public-bean-household-identity]", text: /#{share.workspace.name}/
    assert_select "[data-testid=public-bean-household-logo][src=?]",
      public_bean_media_path(share.token, share.public_media_handle_for(logo.id), variant: :thumbnail)
    assert_select "[data-testid=public-bean-kind-pill]", count: 0
  end

  test "finished hero stats are ordered and omit remaining" do
    bean = beans(:open_household)
    bean.update!(finished_at: Time.zone.parse("2026-06-12 12:00:00"), remaining_grams: 11.5)
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-hero-stat-average-rating]"
    assert_select "[data-testid=public-bean-average-rating-icons][aria-label] .brew-rating-bean", count: 5
    assert_select "[data-testid=public-bean-hero-stat-status]"
    assert_select "[data-testid=public-bean-hero-stat-brews]"
    assert_select "[data-testid=public-bean-hero-stat-remaining]", count: 0
    assert_appears_before "data-testid=\"public-bean-hero-stat-average-rating\"", "data-testid=\"public-bean-hero-stat-status\""
    assert_appears_before "data-testid=\"public-bean-hero-stat-status\"", "data-testid=\"public-bean-hero-stat-brews\""
  end

  test "timeline uses finished endpoint icon for finished bags" do
    bean = beans(:open_household)
    bean.update!(finished_at: Time.zone.parse("2026-06-12 12:00:00"), remaining_grams: 0)
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-journey-end][data-status=finished]"
    assert_select "[data-testid=public-bean-journey-end-finished-icon]"
    assert_select "[data-testid=public-bean-journey-end-open-icon]", count: 0
  end

  test "archived opened bean share remains public with a finished endpoint" do
    bean = beans(:open_household)
    bean.archive!
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-hero-stat-remaining]", count: 0
    assert_select "[data-testid=public-bean-journey-end][data-status=finished]"
  end

  test "public page hides raw attachment ids and original filenames" do
    bean = beans(:open_household)
    photo = attach_photo_with_filename(bean, "private-bean-bag-original.jpg")
    share = create_share(bean:, enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_bean_page_path(share.token)

    assert_response :success
    assert_includes response.body, "/b/#{share.token}/media/"
    assert_no_match "private-bean-bag-original.jpg", response.body
    assert_no_match %r{/media/#{photo.id}(?:[?"])}, response.body
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "public page uses stored snapshot instead of changed live bean fields" do
    share = create_share(enabled: true)
    bean = share.bean
    snapshot = share.snapshot.deep_dup
    snapshot["bean"]["name"] = "Snapshot bean name"
    snapshot["bean"]["public_note"] = "Snapshot public note"
    share.update!(snapshot:)

    bean.update!(name: "Changed live bean name", public_note: "Changed live public note", notes: "Changed private note")

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "body", text: /Snapshot bean name/
    assert_select "body", text: /Snapshot public note/
    assert_select "body", text: /Changed live bean name/, count: 0
    assert_select "body", text: /Changed live public note/, count: 0
    assert_select "body", text: /Changed private note/, count: 0
  end

  test "renders espresso and quick drip brews" do
    bean = beans(:open_household)
    bean.workspace.brews.create!(
      user: users(:two),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral",
      public_note: "Public batch"
    )
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-brew-compact-card][data-method=espresso]"
    assert_select "[data-testid=public-bean-brew-compact-card][data-method=quick_drip]"
    assert_select "body", text: /Quick Drip/
  end

  test "compact brew list marks and links brews with enabled public pages" do
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
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-brew-hero-card]", count: 0
    assert_select "[data-testid=public-bean-brew-compact-card]", minimum: 1
    assert_select "[data-testid=public-bean-brew-shared-marker]", count: 0
    assert_select "[data-testid^='public-bean-brew-native-share']", count: 0
    assert_select "[data-testid=public-bean-brew-rating-metric]", minimum: 1
    assert_select "[data-testid=public-bean-brew-date-chip]", minimum: 1
    assert_select "[data-testid=public-bean-brew-method-chip]", minimum: 1
    assert_select "a[data-testid=public-bean-brew-public-link][href=?]", public_brew_page_path(public_brew_share.token), text: /Shared shot/
    assert_appears_before "data-testid=\"public-bean-brew-date-chip\"", "data-testid=\"public-bean-brew-public-link\""
    assert_appears_before "data-testid=\"public-bean-brew-public-link\"", "data-testid=\"public-bean-brew-method-chip\""
  end

  test "successful public page render records view" do
    share = create_share(enabled: true)

    assert_difference -> { PublicBeanShareView.count }, 1 do
      get public_bean_page_path(share.token), headers: {
        "REMOTE_ADDR" => "198.51.100.40",
        "HTTP_USER_AGENT" => "Roastnode test browser"
      }
    end

    assert_response :success
    view = share.public_bean_share_views.last
    assert_equal "198.51.100.40", view.ip_address
    assert_equal "Roastnode test browser", view.user_agent
    assert_equal 1, share.reload.views_count
  end

  test "password gate does not count until unlocked page is rendered" do
    share = create_share(enabled: true, password: "coffee")

    assert_no_difference -> { PublicBeanShareView.count } do
      get public_bean_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.41" }
    end

    post unlock_public_bean_page_path(share.token), params: { password: "coffee" }
    assert_redirected_to public_bean_page_path(share.token)

    assert_difference -> { PublicBeanShareView.count }, 1 do
      get public_bean_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.41" }
    end
  end

  test "disabled and unknown shares do not record page views" do
    share = create_share(enabled: false)

    assert_no_difference -> { PublicBeanShareView.count } do
      get public_bean_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.42" }
    end
    assert_response :not_found

    assert_no_difference -> { PublicBeanShareView.count } do
      get public_bean_page_path("missing-token"), headers: { "REMOTE_ADDR" => "198.51.100.43" }
    end
    assert_response :not_found
  end

  test "public bean request path and redirects redact bearer tokens for logs" do
    share = create_share(enabled: true, password: "coffee")
    media_handle = "opaque-media-handle"

    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/b/#{share.token}/media/#{media_handle}?token=secret")
    )
    request.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    assert_equal "/b/[FILTERED]/media/[FILTERED]?token=[FILTERED]", request.filtered_path
    assert_equal "[FILTERED]", request.parameter_filter.filter(media_id: media_handle).fetch(:media_id)

    post unlock_public_bean_page_path(share.token), params: { password: "coffee" }

    assert_redirected_to public_bean_page_path(share.token)
    assert_equal "[FILTERED]", response.filtered_location
  end

  private
    def set_comparisons(share, comparisons)
      snapshot = share.snapshot.deep_dup
      snapshot["comparisons"] = snapshot.fetch("comparisons", {}).deep_merge(comparisons)
      share.update!(snapshot:)
    end

    def create_share(bean: beans(:open_household), enabled:, password: nil, selected_photo_attachment_ids: [])
      bean.update!(public_note: "Public bean note.", notes: "Private bean note.")
      brews(:morning_espresso).update!(bean:, public_note: "Public brew note", notes: "Private brew note")
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled:,
        password:,
        title: "Shared bean",
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end

    def attach_photo_with_filename(record, filename)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename:, content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end

    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end
end
