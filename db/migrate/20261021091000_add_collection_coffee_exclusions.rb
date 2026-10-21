class AddCollectionCoffeeExclusions < ActiveRecord::Migration[8.1]
  def change
    add_column :public_bean_collections, :excluded_history_ids, :jsonb, null: false, default: []
  end
end
