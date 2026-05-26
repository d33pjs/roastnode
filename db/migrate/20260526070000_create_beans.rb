class CreateBeans < ActiveRecord::Migration[8.1]
  def change
    create_table :beans do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :roaster_name
      t.string :origin
      t.string :process
      t.date :roast_date
      t.string :roast_level
      t.text :tasting_notes
      t.decimal :bag_size_grams, precision: 10, scale: 2, null: false
      t.decimal :remaining_grams, precision: 10, scale: 2, null: false
      t.date :opened_on
      t.datetime :archived_at
      t.string :purchase_source
      t.string :purchase_url
      t.date :purchased_on
      t.integer :purchase_price_cents
      t.integer :rating
      t.text :notes

      t.timestamps
    end

    add_index :beans, [ :workspace_id, :archived_at ]
  end
end
