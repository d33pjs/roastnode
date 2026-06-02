class NullifyRecipeSourceBrewForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :recipes, column: :source_brew_id
    add_foreign_key :recipes, :brews, column: :source_brew_id, on_delete: :nullify
  end
end
