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
    assert_select "[data-testid=public-bean-brew-card]", minimum: 1
    assert_select "body", text: /Public bean note/
    assert_select "body", text: /Private bean note/, count: 0
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
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
    assert_select "[data-testid=public-bean-brew-card][data-method=espresso]"
    assert_select "[data-testid=public-bean-brew-card][data-method=quick_drip]"
    assert_select "body", text: /Quick Drip/
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
    def create_share(bean: beans(:open_household), enabled:, password: nil)
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
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
