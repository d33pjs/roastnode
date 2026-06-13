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

  test "purchase url label shortens host and compact path" do
    assert_equal "example.com/beans/house...", bean_purchase_url_label("https://example.com/beans/house-blend?ref=abc")
    assert_equal "shop.example.com", bean_purchase_url_label("https://shop.example.com")
  end
end
