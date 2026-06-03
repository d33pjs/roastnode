class AddViewTrackingToPublicBrewShares < ActiveRecord::Migration[8.1]
  def change
    add_column :public_brew_shares, :views_count, :integer, null: false, default: 0
  end
end
