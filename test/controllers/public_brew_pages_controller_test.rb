require "test_helper"

class PublicBrewPagesControllerTest < ActionDispatch::IntegrationTest
  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_brew_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without authentication" do
    share = create_share(enabled: true)
    share.workspace.update!(buy_me_a_coffee_url: "https://buymeacoffee.com/roastnode")

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-page]"
    assert_select "[data-testid=public-brew-hero-card]"
    assert_select "body", text: /Public brew story/
    assert_select "a[href='https://example.test/shot'][data-testid=public-brew-link]", text: /Shot writeup/
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /Private shot link/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "[data-testid=site-footer-github-logo]"
    assert_select "a[data-testid=site-footer-github].h-11"
    assert_select "[data-testid=site-footer-version]", count: 0
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
    assert_select "a[data-testid=site-footer-buy-me-a-coffee].h-11"
    assert_select "[data-testid=site-footer-buy-me-a-coffee-logo]"
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "stale enabled quick drip share returns not found" do
    share = create_share(enabled: true)
    quick_drip = create_quick_drip_brew
    share.update_columns(brew_id: quick_drip.id)

    assert_no_difference -> { PublicBrewShareView.count } do
      get public_brew_page_path(share.token)
    end

    assert_response :not_found
  end

  test "enabled share renders official buy me a coffee config as static local button" do
    share = create_share(enabled: true)
    share.workspace.update!(
      buy_me_a_coffee_display_mode: "official_badge",
      buy_me_a_coffee_slug: "d33p.js",
      buy_me_a_coffee_text: "Buy me a coffee"
    )

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://www.buymeacoffee.com/d33p.js", text: /Buy me a coffee/
    assert_select "[data-testid=site-footer-buy-me-a-coffee-logo]"
    assert_select "script[src*='buymeacoffee']", count: 0
    assert_select "script[data-testid=site-footer-buy-me-a-coffee]", count: 0
    assert_select "[data-testid=site-footer-version]", count: 0
  end

  test "successful public page render records a full ip page view" do
    share = create_share(enabled: true)

    assert_difference -> { PublicBrewShareView.count }, 1 do
      get public_brew_page_path(share.token), headers: {
        "REMOTE_ADDR" => "198.51.100.24",
        "HTTP_USER_AGENT" => "Roastnode test browser"
      }
    end

    assert_response :success
    view = share.public_brew_share_views.last
    assert_equal "198.51.100.24", view.ip_address
    assert_equal "Roastnode test browser", view.user_agent
    assert_equal 1, share.reload.views_count
  end

  test "password gate does not count until the unlocked page is rendered" do
    share = create_share(enabled: true, password: "espresso")

    assert_no_difference -> { PublicBrewShareView.count } do
      get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.25" }
    end

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    assert_difference -> { PublicBrewShareView.count }, 1 do
      get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.25" }
    end

    assert_equal "198.51.100.25", share.public_brew_share_views.last.ip_address
  end

  test "disabled and unknown shares do not record page views" do
    share = create_share(enabled: false)

    assert_no_difference -> { PublicBrewShareView.count } do
      get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.26" }
    end
    assert_response :not_found

    assert_no_difference -> { PublicBrewShareView.count } do
      get public_brew_page_path("missing-token"), headers: { "REMOTE_ADDR" => "198.51.100.27" }
    end
    assert_response :not_found
  end

  test "malformed overlong forwarded ip does not prevent public page render" do
    share = create_share(enabled: true)
    overlong_ip = "198.51.100.#{'1' * 300}"

    get public_brew_page_path(share.token), headers: {
      "REMOTE_ADDR" => overlong_ip,
      "HTTP_X_FORWARDED_FOR" => overlong_ip
    }

    assert_response :success
    if (view = share.public_brew_share_views.last)
      assert_operator view.ip_address.length, :<=, 255
    end
  end

  test "public page renders media handles without attachment ids or private media routes" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_brew_page_path(share.token)

    assert_response :success
    assert_includes response.body, "/s/#{share.token}/media/"
    assert_no_match %r{/media/#{photo.id}(?:[?"])}, response.body
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "public hero mirrors private metrics with the shared backdrop and recipient byline" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-hero-card]"
    assert_select "[data-testid=public-brew-dose]"
    assert_select "[data-testid=public-brew-ratio]"
    assert_select "[data-testid=public-brew-grind]"
    assert_select "[data-testid=public-brew-rating]"
    assert_select "[data-testid=public-brew-rating] [data-testid=public-brew-rating-icons][aria-label=?]",
      I18n.t("brews.show.rating_beans", rating: share.snapshot.dig("brew", "rating"), maximum: 5) do
        assert_select ".rating-bean--filled", 4
        assert_select ".rating-bean--empty", 1
      end
    assert_includes response.body, ".brew-rating-bean"
    assert_select "[data-testid=public-brew-balance]"
    assert_select "[data-testid=public-brew-retention]", count: 0
    assert_select "[data-testid=public-brew-card-workspace]", count: 0
    assert_select "[data-testid=public-brew-hero-card]", text: /Espresso/, count: 0
    assert_select "[data-testid=public-brew-hero-upper] [data-testid=brew-hero-backdrop][aria-hidden=true]"
    assert_select "[data-testid=public-brew-hero-overlay] [data-testid=public-brew-recipient-byline]",
      text: I18n.t(
        "brews.recipients.byline",
        logger: share.snapshot.dig("user", "display_label"),
        recipient: I18n.t("brews.recipients.themself")
      )
    assert_select "[data-testid=brew-hero-bean-image]", count: 0
    assert_select "[data-testid=brew-hero-brew-image]", count: 0
    assert_select "a[data-testid=public-brew-bean-anchor][href='##{public_bean_anchor_for(share)}']", text: /Good Coffee/
    assert_select "a[data-testid=public-brew-bean-anchor][href='##{public_bean_anchor_for(share)}']", text: /House Blend/
    assert_select "[data-testid=public-brew-identity-strip]"
    assert_select "[data-testid=public-brew-identity-strip]" do |elements|
      classes = elements.first["class"].split
      assert_includes classes, "grid-cols-2"
      assert_not_includes classes, "sm:grid-cols-2"
    end
    assert_select "[data-testid=public-household-identity].self-start", text: /Household/
    assert_select "[data-testid=public-user-identity].self-start", text: /User/
    assert_select "[data-testid=public-brew-chart-grid].brew-chart-grid"
    assert_select "[data-testid=public-brew-preinfusion-guide]"
    assert_select "[data-testid=public-brew-first-drip-callout]"
    assert_select "[data-testid=public-brew-total-time-guide]"
    assert_select "[data-testid=public-brew-temperature-callout]"
    assert_select "[data-testid=public-brew-preinfusion-label]", text: /5s/
    assert_select "[data-testid=public-brew-first-drip-label]", text: /8s/
    assert_select "[data-testid=public-brew-total-time-label]", text: /28s/
    assert_select "[data-testid=public-brew-temperature-label]", text: /93/
    assert_select "[data-testid=public-brew-hero-upper] [data-testid=public-brew-chart-grid]", count: 0
    assert_select "[data-testid=public-brew-hero-upper] [data-testid=public-brew-gear-footer]", count: 0
  end

  test "public hero renders all selected primary image states through opaque hero handles" do
    brew = brews(:morning_espresso)
    bean_primary = attach_photo(brew.bean)
    bean_non_primary = attach_photo(brew.bean)
    brew_primary = attach_photo(brew)
    brew_non_primary = attach_photo(brew)
    brew.bean.set_primary_photo!(bean_primary)
    brew.set_primary_photo!(brew_primary)
    share = create_share(enabled: true)
    cases = {
      both: [ [ bean_primary.id, brew_primary.id ], true, true, true ],
      bean_only: [ [ bean_primary.id ], true, false, false ],
      brew_only: [ [ brew_primary.id ], false, true, false ],
      neither: [ [], false, false, false ],
      selected_non_primary: [ [ bean_non_primary.id, brew_non_primary.id ], false, false, false ]
    }

    cases.each do |name, (selected_ids, bean_visible, brew_visible, blend_visible)|
      snapshot = PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: share.title,
        selected_photo_attachment_ids: selected_ids
      ).call
      share.update!(selected_photo_attachment_ids: selected_ids, snapshot:)

      get public_brew_page_path(share.token)

      assert_response :success, name.to_s
      assert_select "[data-testid=public-brew-hero-upper] [data-testid=brew-hero-backdrop]", 1
      assert_select "[data-testid=brew-hero-bean-half]", 1
      assert_select "[data-testid=brew-hero-brew-half]", 1
      assert_select "img[data-testid=brew-hero-bean-image][alt=''].object-contain", count: bean_visible ? 1 : 0
      assert_select "img[data-testid=brew-hero-brew-image][alt=''].object-cover", count: brew_visible ? 1 : 0
      assert_select "[data-testid=brew-hero-center-blend]", count: blend_visible ? 1 : 0
      if bean_visible || brew_visible
        assert_select "[data-testid=brew-hero-bean-image], [data-testid=brew-hero-brew-image]" do |images|
          images.each do |image|
            assert_match %r{\A/s/#{Regexp.escape(share.token)}/media/[0-9a-f]{32}\?variant=hero\z}, image["src"]
          end
        end
      else
        assert_select "[data-testid=brew-hero-bean-image], [data-testid=brew-hero-brew-image]", count: 0
      end
      [ bean_primary, bean_non_primary, brew_primary, brew_non_primary ].each do |attachment|
        assert_no_match %r{/media_attachments/#{attachment.id}(?:[/?"']|$)}, response.body
        assert_no_match(/attachment_id=#{attachment.id}(?:[&"']|$)/, response.body)
        assert_no_match(/data-attachment-id=["']#{attachment.id}["']/, response.body)
      end
      assert_no_match %r{/media_attachments/|/rails/active_storage}, response.body
      assert_no_match(/photo\.jpg|signed_id|X-Amz-Signature/, response.body)
    end
  end

  test "public hero renders a decorative logger and current household recipient avatar pair" do
    brew = brews(:morning_espresso)
    users(:one).update!(display_name: "Jens")
    users(:two).update!(display_name: "Petra")
    logger_avatar = attach_named_photo(users(:one), :avatar, filename: "jens-private.jpg")
    recipient_avatar = attach_named_photo(users(:two), :avatar, filename: "petra-private.jpg")
    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-recipient-byline]", text: "Logged by Jens for Petra"
    assert_select "img[data-testid=public-brew-logger-avatar][alt='']", 1 do |images|
      assert_match %r{\A/s/#{Regexp.escape(share.token)}/media/[0-9a-f]{32}\?variant=thumbnail\z}, images.first["src"]
    end
    assert_select "img[data-testid=public-brew-recipient-avatar][alt='']", 1 do |images|
      assert_match %r{\A/s/#{Regexp.escape(share.token)}/media/[0-9a-f]{32}\?variant=thumbnail\z}, images.first["src"]
    end
    [ logger_avatar, recipient_avatar ].each do |attachment|
      assert_no_match %r{/media/#{attachment.id}(?:[?"']|$)}, response.body
    end
    assert_no_match(/one@example\.com|two@example\.com|jens-private\.jpg|petra-private\.jpg|recipient_name|guest_name|served_for_guest|cup_style/, response.body)
  end

  test "public guest byline never renders its private name or email" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Secret Anna", cup_style: "Secret Cup")
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-recipient-byline]", text: /for a guest/
    assert_no_match(/Secret Anna|Secret Cup|recipient_name|guest_name|served_for_guest|cup_style|one@example\.com/, response.body)
    assert_select "[data-testid=public-brew-recipient-avatar]", count: 0
  end

  test "public hero omits optional timing markers when snapshot values are absent" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot["brew"].delete("preinfusion_seconds")
    snapshot["brew"].delete("first_drip_seconds")
    share.update!(snapshot:)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-preinfusion-label]", count: 0
    assert_select "[data-testid=public-brew-first-drip-label]", count: 0
    assert_select "[data-testid=public-brew-total-time-label]", text: /28s/
    assert_select "[data-testid=public-brew-hero-card]", text: /Unknown/, count: 0
  end

  test "public photos use contain cards and lightbox controls" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = create_share(enabled: true, selected_photo_attachment_ids: [ photo.id ])

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-controller~='public-lightbox']"
    assert_select "button[data-action*='public-lightbox#open'][data-public-lightbox-index-param='0'][data-full-src]"
    assert_select "img[data-testid=public-brew-gallery-photo].object-contain"
    assert_select "button[aria-label='#{I18n.t("public_brew_pages.show.open_photo")}'][data-action*='public-lightbox#open']"
    assert_select "[data-public-lightbox-target=dialog][role=dialog][aria-modal=true]"
    assert_select "button[data-action*='public-lightbox#previous']", text: /#{I18n.t("public_brew_pages.show.previous_photo")}/
    assert_select "button[data-action*='public-lightbox#next']", text: /#{I18n.t("public_brew_pages.show.next_photo")}/
    assert_no_match "/media_attachments", response.body
    assert_no_match "/rails/active_storage", response.body
  end

  test "public product photos expose an accessible lightbox name" do
    brew = brews(:morning_espresso)
    bean_photo = attach_photo(brew.bean)
    share = create_share(enabled: true, selected_photo_attachment_ids: [ bean_photo.id ])

    get public_brew_page_path(share.token)

    assert_response :success
    name = share.snapshot.dig("bean", "display_name")
    assert_select "button[aria-label='#{I18n.t("public_brew_pages.show.open_named_photo", name:)}'][data-action*='public-lightbox#open'][data-public-lightbox-index-param='0']"
    assert_select "[data-testid=public-product-section][data-kind=bean].md\\:items-start"
    assert_select "[data-testid=public-bean-thumbnail-rail]"
    assert_select "button[data-testid=public-bean-thumbnail][data-action*='public-lightbox#open']"
  end

  test "public links render with visible link icon treatment" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "a[data-testid=public-brew-link] [data-testid=public-link-icon]", text: "🔗"
  end

  test "public bean section shows safe facts but ignores a legacy purchase price" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot["bean"]["purchase_price_cents"] = 87_654_321
    snapshot["bean"]["public_note"] = "Visible public bean section."
    share.update!(snapshot:)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-product-section][data-kind=bean]", text: /Visible public bean section/
    assert_select "[data-testid=public-bean-fact]", text: /Bought/
    assert_select "[data-testid=public-bean-fact]", text: /Opened/
    assert_select "[data-testid=public-bean-fact]", text: /€876,543\.21/, count: 0
    assert_no_match "€876,543.21", response.body
    assert_select "body", text: /Local roaster/, count: 0
  end

  test "password protected share shows gate until unlocked" do
    share = create_share(enabled: true, password: "espresso")

    get public_brew_page_path(share.token)
    assert_response :success
    assert_select "form[action=?]", unlock_public_brew_page_path(share.token)
    assert_select "[data-testid=public-brew-page]", count: 0

    post unlock_public_brew_page_path(share.token), params: { password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "body", text: /#{I18n.t("public_brew_pages.unlock.failed")}/

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    get public_brew_page_path(share.token)
    assert_response :success
    assert_select "[data-testid=public-brew-page]"
  end

  test "password unlock is rate limited by share token digest and remote ip" do
    ActionController::Base.cache_store.clear
    share = create_share(enabled: true, password: "espresso")
    cache_keys = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      cache_keys << payload.fetch(:cache_key)
    end

    ActiveSupport::Notifications.subscribed(callback, "rate_limit.action_controller") do
      10.times do
        post unlock_public_brew_page_path(share.token),
          params: { password: "wrong" },
          headers: { "REMOTE_ADDR" => "203.0.113.10" }
        assert_response :unprocessable_entity
      end

      post unlock_public_brew_page_path(share.token),
        params: { password: "wrong" },
        headers: { "REMOTE_ADDR" => "203.0.113.10" }
    end

    assert_response :too_many_requests
    assert_select "body", text: /#{I18n.t("public_brew_pages.unlock.rate_limited")}/
    assert_equal 1, cache_keys.length
    assert_not_includes cache_keys.first, share.token
    assert_includes cache_keys.first, PublicBrewShare.token_digest_for(share.token)
  ensure
    ActionController::Base.cache_store.clear
  end

  test "password change invalidates existing public page unlock" do
    share = create_share(enabled: true, password: "espresso")

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
    assert_redirected_to public_brew_page_path(share.token)

    get public_brew_page_path(share.token)
    assert_response :success
    assert_select "[data-testid=public-brew-page]"

    share.update!(password: "ristretto")

    get public_brew_page_path(share.token)
    assert_response :success
    assert_select "form[action=?]", unlock_public_brew_page_path(share.token)
    assert_select "[data-testid=public-brew-page]", count: 0
  end

  test "equipment purchase prices in snapshot are not rendered publicly" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot["equipment"] = [
      {
        "role" => "grinder",
        "name" => "Secret grinder",
        "display_name" => "Secret grinder",
        "purchase_price_cents" => 123_456
      }
    ]
    share.update!(snapshot:)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "body", text: /Secret grinder/
    assert_no_match "€1,234.56", response.body
  end

  test "sparse stale snapshot renders with public fallbacks" do
    share = create_share(enabled: true)
    share.update!(snapshot: {
      "title" => "Sparse share",
      "brew" => { "occurred_at" => "not-a-date" },
      "bean" => {},
      "equipment" => [ { "role" => nil, "name" => nil } ],
      "tools" => [ {} ],
      "photos" => []
    })

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-page]"
    assert_select "body", text: /Sparse share/
    assert_select "body", text: /#{I18n.t("public_brew_pages.show.unknown")}/
    assert_select "[data-testid=public-brew-recipient-byline]", text: "Logged by #{I18n.t('public_brew_pages.show.unknown')} for someone"
    assert_select "[data-testid=public-brew-recipient-byline]", text: /for themself/, count: 0
  end

  test "malformed recipient payloads fail closed to someone" do
    share = create_share(enabled: true)

    [ nil, "household_member", [], { "kind" => "unsupported" } ].each do |malformed_recipient|
      snapshot = share.snapshot.deep_dup
      snapshot["brew"]["recipient"] = malformed_recipient
      share.update!(snapshot:)

      get public_brew_page_path(share.token)

      assert_response :success
      assert_select "[data-testid=public-brew-recipient-byline]", text: /for someone/
      assert_select "[data-testid=public-brew-recipient-avatar]", count: 0
    end
  end

  test "household recipient without a safe label uses the anonymous household fallback" do
    share = create_share(enabled: true)
    snapshot = share.snapshot.deep_dup
    snapshot["brew"]["recipient"] = { "kind" => "household_member", "display_label" => "" }
    share.update!(snapshot:)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-recipient-byline]", text: /for a household member/
  end

  test "stale legacy media references render without public page failure" do
    share = create_share(enabled: true)
    stale_attachment_id = 999_999
    share.update!(snapshot: {
      "title" => "Stale media share",
      "workspace" => { "name" => "Household", "logo_attachment_id" => stale_attachment_id },
      "user" => { "display_label" => "user", "avatar_attachment_id" => stale_attachment_id },
      "brew" => { "method" => "espresso", "occurred_at" => Time.current.iso8601 },
      "bean" => { "name" => "Bean", "photo_attachment_id" => stale_attachment_id },
      "equipment" => [
        { "role" => "grinder", "name" => "Grinder", "photo_attachment_id" => stale_attachment_id }
      ],
      "photos" => [ { "attachment_id" => stale_attachment_id } ]
    })

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-page]"
    assert_select "img[src*='/media/']", count: 0
    assert_select "body", text: /Stale media share/
  end

  test "public share request path and redirects redact bearer tokens for logs" do
    share = create_share(enabled: true, password: "espresso")
    media_handle = share.public_media_handle_for(share.public_attachment_ids.first || 1) || "abc123"

    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/s/#{share.token}/media/#{media_handle}?token=secret")
    )
    request.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    assert_equal "/s/[FILTERED]/media/[FILTERED]?token=[FILTERED]", request.filtered_path
    assert_equal "[FILTERED]", request.parameter_filter.filter(media_id: media_handle).fetch(:media_id)

    post unlock_public_brew_page_path(share.token), params: { password: "espresso" }

    assert_redirected_to public_brew_page_path(share.token)
    assert_equal "[FILTERED]", response.filtered_location
  end

  private
    def create_share(enabled:, password: nil, selected_photo_attachment_ids: [])
      brew = brews(:morning_espresso)
      brew.update!(public_note: "Public brew story.", notes: "Private brew note.")
      brew.record_links.destroy_all
      brew.record_links.create!(
        label: "Shot writeup",
        url: "https://example.test/shot",
        kind: "info",
        visibility: "public"
      )
      brew.record_links.create!(
        label: "Private shot link",
        url: "https://example.test/private-shot",
        kind: "info",
        visibility: "private"
      )
      snapshot = PublicBrewShareSnapshotBuilder.new(
        brew:,
        title: "Shared shot",
        selected_photo_attachment_ids:
      ).call

      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared shot",
        enabled:,
        password:,
        selected_photo_attachment_ids:,
        snapshot:
      )
    end

    def create_quick_drip_brew
      workspaces(:household).brews.create!(
        user: users(:one),
        method: "quick_drip",
        bean: beans(:second_open_household),
        brewer: equipment(:household_brewer),
        machine_cups: 6,
        bean_weight_grams: 30,
        taste_balance: "neutral"
      )
    end

    def public_bean_anchor_for(share)
      bean = share.snapshot.fetch("bean")
      [ "bean", bean["display_name"].presence || bean["name"] ].join("-").parameterize
    end
end
