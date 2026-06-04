require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "buy me a coffee url is optional" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = ""

    assert workspace.valid?
  end

  test "buy me a coffee url accepts buymeacoffee https urls" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = " https://www.buymeacoffee.com/roastnode "

    assert workspace.valid?
    assert_equal "https://www.buymeacoffee.com/roastnode", workspace.buy_me_a_coffee_url
  end

  test "buy me a coffee url rejects non-buymeacoffee hosts and unsafe schemes" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = "https://example.test/roastnode"
    assert_not workspace.valid?

    workspace.buy_me_a_coffee_url = "javascript:alert(1)"
    assert_not workspace.valid?
  end

  test "buy me a coffee badge config defaults to link mode" do
    workspace = Workspace.new(name: "Test", default_currency: "EUR")

    assert_equal "link", workspace.buy_me_a_coffee_display_mode
    assert_not workspace.official_buy_me_a_coffee_badge?
    assert_nil workspace.site_footer_buy_me_a_coffee
  end

  test "official buy me a coffee badge requires a slug and builds footer config" do
    workspace = workspaces(:household)

    workspace.assign_attributes(
      buy_me_a_coffee_display_mode: "official_badge",
      buy_me_a_coffee_slug: " d33p.js ",
      buy_me_a_coffee_text: " Support the beans "
    )

    assert workspace.valid?
    assert_equal "d33p.js", workspace.buy_me_a_coffee_slug
    assert_equal "Support the beans", workspace.buy_me_a_coffee_text
    assert_equal(
      {
        mode: :official_badge,
        slug: "d33p.js",
        text: "Support the beans"
      },
      workspace.site_footer_buy_me_a_coffee
    )
  end

  test "official buy me a coffee badge rejects missing and unsafe slugs" do
    workspace = workspaces(:household)
    workspace.buy_me_a_coffee_display_mode = "official_badge"

    workspace.buy_me_a_coffee_slug = ""
    assert_not workspace.valid?

    workspace.buy_me_a_coffee_slug = "bad/slug"
    assert_not workspace.valid?

    workspace.buy_me_a_coffee_slug = "https://buymeacoffee.com/roastnode"
    assert_not workspace.valid?
  end

  test "buy me a coffee badge text has a length limit" do
    workspace = workspaces(:household)

    workspace.assign_attributes(
      buy_me_a_coffee_display_mode: "official_badge",
      buy_me_a_coffee_slug: "roastnode",
      buy_me_a_coffee_text: "x" * 81
    )

    assert_not workspace.valid?
  end

  test "simple buy me a coffee link builds footer config" do
    workspace = workspaces(:household)
    workspace.buy_me_a_coffee_url = "https://buymeacoffee.com/roastnode"

    assert_equal(
      {
        mode: :link,
        url: "https://buymeacoffee.com/roastnode"
      },
      workspace.site_footer_buy_me_a_coffee
    )
  end
end
