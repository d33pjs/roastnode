class AddDuplicateSourceToBeans < ActiveRecord::Migration[8.1]
  def change
    add_reference :beans, :duplicated_from_bean, foreign_key: { to_table: :beans }
  end
end
