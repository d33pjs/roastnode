class AddMediaToRecipesAndPublicRecipeShares < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :primary_photo_attachment_id, :bigint
    add_index :recipes, :primary_photo_attachment_id

    add_column :public_recipe_shares, :selected_photo_attachment_ids, :integer, array: true, null: false, default: []
  end
end
