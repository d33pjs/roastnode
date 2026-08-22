class ReplaceBrewGuestFieldsWithRecipient < ActiveRecord::Migration[8.1]
  def up
    add_column :brews, :recipient_kind, :string, null: false, default: "self"
    add_reference :brews, :recipient_user, null: true, foreign_key: { to_table: :users }
    add_column :brews, :recipient_name, :string
    backfill_recipient_columns(:brews)
    remove_column :brews, :served_for_guest, :boolean
    remove_column :brews, :guest_name, :string
    add_check_constraint :brews, <<~SQL.squish, name: "brews_recipient_shape"
      (recipient_kind = 'self' AND recipient_user_id IS NULL AND recipient_name IS NULL) OR
      (recipient_kind = 'household_member' AND recipient_user_id IS NOT NULL AND recipient_name IS NULL) OR
      (recipient_kind = 'guest' AND recipient_user_id IS NULL)
    SQL
  end

  def down
    remove_check_constraint :brews, name: "brews_recipient_shape"
    add_column :brews, :served_for_guest, :boolean, null: false, default: false
    add_column :brews, :guest_name, :string
    execute <<~SQL.squish
      UPDATE brews
      SET served_for_guest = (recipient_kind = 'guest'),
          guest_name = CASE WHEN recipient_kind = 'guest' THEN recipient_name ELSE NULL END
    SQL
    remove_reference :brews, :recipient_user, foreign_key: { to_table: :users }
    remove_column :brews, :recipient_name, :string
    remove_column :brews, :recipient_kind, :string
  end

  def backfill_recipient_columns(table_name)
    table = connection.quote_table_name(table_name)
    execute <<~SQL.squish
      UPDATE #{table}
      SET recipient_kind = CASE WHEN served_for_guest THEN 'guest' ELSE 'self' END,
          recipient_user_id = NULL,
          recipient_name = CASE
            WHEN served_for_guest THEN NULLIF(BTRIM(guest_name), '')
            ELSE NULL
          END
    SQL
  end
end
