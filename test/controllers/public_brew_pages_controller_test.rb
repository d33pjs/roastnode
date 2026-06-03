require "test_helper"

class PublicBrewPagesControllerTest < ActionDispatch::IntegrationTest
  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_brew_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without authentication" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-page]"
    assert_select "[data-testid=public-brew-hero-card]"
    assert_select "body", text: /Public brew story/
    assert_select "a[href='https://example.test/shot'][data-testid=public-brew-link]", text: /Shot writeup/
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /Private shot link/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
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

  test "public hero mirrors private card metrics without in-card identity clutter" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-brew-hero-card]"
    assert_select "[data-testid=public-brew-dose]"
    assert_select "[data-testid=public-brew-ratio]"
    assert_select "[data-testid=public-brew-grind]"
    assert_select "[data-testid=public-brew-rating]"
    assert_select "[data-testid=public-brew-balance]"
    assert_select "[data-testid=public-brew-retention]", count: 0
    assert_select "[data-testid=public-brew-card-workspace]", count: 0
    assert_select "[data-testid=public-brew-card-byline]", count: 0
    assert_select "[data-testid=public-brew-hero-card]", text: /Espresso/, count: 0
    assert_select "[data-testid=public-brew-identity-strip]"
    assert_select "[data-testid=public-brew-preinfusion-label]", text: /5s/
    assert_select "[data-testid=public-brew-first-drip-label]", text: /8s/
    assert_select "[data-testid=public-brew-total-time-label]", text: /28s/
    assert_select "[data-testid=public-brew-temperature-label]", text: /93/
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
    assert_select "button[data-action*='public-lightbox#open'][data-full-src]"
    assert_select "img[data-testid=public-brew-gallery-photo].object-contain"
    assert_select "button[aria-label='#{I18n.t("public_brew_pages.show.open_photo")}'][data-action*='public-lightbox#open']"
    assert_select "[data-public-lightbox-target=dialog][role=dialog][aria-modal=true]"
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
    assert_select "button[aria-label='#{I18n.t("public_brew_pages.show.open_named_photo", name:)}'][data-action*='public-lightbox#open']"
  end

  test "public links render with visible link icon treatment" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "a[data-testid=public-brew-link] [data-testid=public-link-icon]", text: "🔗"
  end

  test "public bean section shows safe bean facts" do
    share = create_share(enabled: true)

    get public_brew_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-product-section][data-kind=bean]"
    assert_select "[data-testid=public-bean-fact]", text: /Bought/
    assert_select "[data-testid=public-bean-fact]", text: /Opened/
    assert_select "[data-testid=public-bean-fact]", text: /€/
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
end
