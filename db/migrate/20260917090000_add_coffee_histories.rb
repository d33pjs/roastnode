class AddCoffeeHistories < ActiveRecord::Migration[8.1]
  def up
    create_table :coffee_histories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.timestamps
    end

    add_reference :beans, :coffee_history, foreign_key: true
    backfill_coffee_histories
    change_column_null :beans, :coffee_history_id, false
  end

  def down
    remove_reference :beans, :coffee_history, foreign_key: true
    drop_table :coffee_histories
  end

  private
    def backfill_coffee_histories
      now = connection.quote(Time.current)

      select_all("SELECT id, workspace_id, duplicated_from_bean_id FROM beans ORDER BY workspace_id, id").group_by do |row|
        row.fetch("workspace_id")
      end.each do |workspace_id, rows|
        ids = rows.to_h { |row| [ row.fetch("id"), row ] }
        parent = ids.keys.to_h { |id| [ id, id ] }
        find = lambda do |id|
          parent[id] = parent.fetch(parent[id]) while parent[id] != parent.fetch(parent[id])
          parent[id]
        end

        rows.each do |row|
          source_id = row["duplicated_from_bean_id"]
          next unless source_id && ids.key?(source_id)

          left = find.call(row.fetch("id"))
          right = find.call(source_id)
          parent[left] = right if left != right
        end

        rows.group_by { |row| find.call(row.fetch("id")) }.values.each do |component|
          history_id = insert("INSERT INTO coffee_histories (workspace_id, created_at, updated_at) VALUES (#{connection.quote(workspace_id)}, #{now}, #{now})")
          bean_ids = component.map { |row| connection.quote(row.fetch("id")) }.join(", ")
          execute("UPDATE beans SET coffee_history_id = #{connection.quote(history_id)} WHERE id IN (#{bean_ids})")
        end
      end
    end
end
