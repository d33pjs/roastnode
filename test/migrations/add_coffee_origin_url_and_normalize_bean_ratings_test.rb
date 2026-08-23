require "test_helper"
require Rails.root.join(
  "db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings"
).to_s

class AddCoffeeOriginUrlAndNormalizeBeanRatingsTest < ActiveSupport::TestCase
  test "normalizes legacy zero ratings to null" do
    bean = beans(:open_household)
    bean.update_column(:rating, 0)

    migration = AddCoffeeOriginUrlAndNormalizeBeanRatings.new
    migration.send(:normalize_legacy_bean_ratings)

    assert_nil bean.reload.rating
  end
end
