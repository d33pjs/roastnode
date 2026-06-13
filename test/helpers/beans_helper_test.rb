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
end
