class CreateExternalCoffees < ActiveRecord::Migration[8.1]
  def change
    create_table :external_coffees do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :occurred_at, null: false
      t.string :drink_type, null: false
      t.string :drink_size
      t.string :place_name
      t.string :place_location
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.integer :price_cents
      t.string :currency, null: false
      t.string :acidity_balance, default: "unknown", null: false
      t.string :intensity, default: "unknown", null: false
      t.integer :rating
      t.text :notes
      t.text :public_note
      t.references :primary_photo_attachment, foreign_key: { to_table: :active_storage_attachments }

      t.timestamps

      t.index [ :workspace_id, :occurred_at ]
      t.index [ :workspace_id, :drink_type ]
      t.index [ :workspace_id, :place_name ]
    end
  end
end
