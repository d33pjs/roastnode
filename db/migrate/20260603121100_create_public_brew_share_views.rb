class CreatePublicBrewShareViews < ActiveRecord::Migration[8.1]
  def change
    create_table :public_brew_share_views do |t|
      t.references :public_brew_share, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :ip_address, null: false
      t.string :user_agent
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :public_brew_share_views,
      [ :public_brew_share_id, :viewed_at, :id ],
      name: "idx_public_brew_share_views_recent"
  end
end
