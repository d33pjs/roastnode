class AddBuyMeACoffeeUrlToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :buy_me_a_coffee_url, :string
  end
end
