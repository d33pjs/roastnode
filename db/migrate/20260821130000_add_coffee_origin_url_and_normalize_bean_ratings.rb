class AddCoffeeOriginUrlAndNormalizeBeanRatings < ActiveRecord::Migration[8.1]
  def up
    add_column :beans, :coffee_origin_url, :string
    normalize_legacy_bean_ratings
  end

  def down
    remove_column :beans, :coffee_origin_url
  end

  private
    def normalize_legacy_bean_ratings
      execute("UPDATE beans SET rating = NULL WHERE rating = 0")
    end
end
