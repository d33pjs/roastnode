class AddBuyMeACoffeeBadgeConfigToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :buy_me_a_coffee_display_mode, :string, null: false, default: "link"
    add_column :workspaces, :buy_me_a_coffee_slug, :string
    add_column :workspaces, :buy_me_a_coffee_text, :string
  end
end
