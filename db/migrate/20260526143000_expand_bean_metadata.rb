class ExpandBeanMetadata < ActiveRecord::Migration[8.1]
  def change
    change_table :beans, bulk: true do |t|
      t.string :roast_type, null: false, default: "unknown"
      t.decimal :roast_degree, precision: 3, scale: 1
      t.string :blend_type, null: false, default: "unknown"
      t.boolean :decaffeinated, null: false, default: false
      t.string :country
      t.string :region
      t.string :farm
      t.string :farmer
      t.string :elevation
      t.string :variety
      t.string :harvested
      t.string :blend_percentage
    end
  end
end
