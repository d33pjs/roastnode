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
    assert_select "a[href='https://example.test/shot'][data-testid=public-brew-link]", text: "Shot writeup"
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /Private shot link/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
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
