class AddQuickDripLogging < ActiveRecord::Migration[8.1]
  def change
    add_reference :brews, :brewer, foreign_key: { to_table: :equipment }, index: true
    add_column :brews, :machine_cups, :decimal, precision: 8, scale: 2
    add_column :brews, :coffee_spoons, :decimal, precision: 8, scale: 2
    add_column :brews, :grams_per_coffee_spoon, :decimal, precision: 8, scale: 2
    add_column :brews, :coffee_amount_source, :string, default: "measured", null: false

    add_column :beans, :grind_state, :string, default: "whole_bean", null: false

    add_column :users, :enabled_brew_methods, :jsonb, default: %w[espresso quick_drip], null: false
    add_column :users, :grams_per_coffee_spoon, :decimal, precision: 6, scale: 2
  end
end
