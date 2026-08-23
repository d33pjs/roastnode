require "test_helper"

class BeansHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "bean origin display falls back through structured origin fields" do
    bean = Bean.new(country: "Colombia", region: "Huila", continent: "South America")
    assert_equal "Colombia", bean_origin_label(bean)

    bean.country = ""
    assert_equal "Huila", bean_origin_label(bean)

    bean.region = ""
    assert_equal "South America", bean_origin_label(bean)

    bean.continent = ""
    assert_equal I18n.t("beans.show.unknown_origin"), bean_origin_label(bean)
  end

  test "bean origin display falls back to legacy origin after structured fields" do
    bean = Bean.new(origin: "Antigua")

    assert_equal "Antigua", bean_origin_label(bean)
  end

  test "purchase url label shortens host and compact path" do
    assert_equal "example.com/beans/house...", bean_purchase_url_label("https://example.com/beans/house-blend?ref=abc")
    assert_equal "example.com/beans/house...", bean_purchase_url_label(" https://example.com/beans/house-blend?ref=abc ")
    assert_equal "shop.example.com", bean_purchase_url_label("https://shop.example.com")
  end

  test "purchase url href only allows http and https urls with hosts" do
    assert_equal "https://example.com/beans", bean_purchase_url_href("https://example.com/beans")
    assert_equal "http://example.com/beans", bean_purchase_url_href(" http://example.com/beans ")
    assert_nil bean_purchase_url_href("javascript:alert(1)")
    assert_nil bean_purchase_url_href("data:text/html,<p>x</p>")
    assert_nil bean_purchase_url_href("example.com/path")
    assert_nil bean_purchase_url_href("https:///path")
  end

  test "private system links expose separate safe purchase and origin entries" do
    bean = Bean.new(
      purchase_url: "https://shop.example/bean",
      coffee_origin_url: "https://origin.example/coffee"
    )

    assert_equal(
      [
        {
          label: "Purchase URL",
          url: "https://shop.example/bean",
          kind: "buy",
          visibility: "private",
          testid: "bean-system-purchase-url"
        },
        {
          label: "Origin Coffee URL",
          url: "https://origin.example/coffee",
          kind: "info",
          visibility: "private",
          testid: "bean-system-origin-url"
        }
      ],
      bean_private_system_links(bean)
    )
  end

  test "private system links omit blank and unsafe legacy urls independently" do
    bean = Bean.new(purchase_url: "javascript:alert(1)", coffee_origin_url: "https://origin.example/coffee")

    assert_equal [
      {
        label: "Origin Coffee URL",
        url: "https://origin.example/coffee",
        kind: "info",
        visibility: "private",
        testid: "bean-system-origin-url"
      }
    ], bean_private_system_links(bean)

    bean.purchase_url = "https://shop.example/bean"
    bean.coffee_origin_url = "data:text/html,<p>x</p>"

    assert_equal [
      {
        label: "Purchase URL",
        url: "https://shop.example/bean",
        kind: "buy",
        visibility: "private",
        testid: "bean-system-purchase-url"
      }
    ], bean_private_system_links(bean)

    bean.purchase_url = ""
    bean.coffee_origin_url = nil

    assert_empty bean_private_system_links(bean)
  end
end
