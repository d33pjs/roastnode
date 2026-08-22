require "test_helper"
require Rails.root.join("db/migrate/20260821110000_replace_brew_guest_fields_with_recipient")

class ReplaceBrewGuestFieldsWithRecipientTest < ActiveSupport::TestCase
  TABLE = :recipient_migration_brews

  setup do
    connection.create_table(TABLE) do |t|
      t.boolean :served_for_guest, null: false, default: false
      t.string :guest_name
      t.string :recipient_kind, null: false, default: "self"
      t.bigint :recipient_user_id
      t.string :recipient_name
    end
  end

  teardown { connection.drop_table(TABLE, if_exists: true) }

  def connection = ActiveRecord::Base.connection

  test "backfills legacy guests without name matching and all other rows as self" do
    connection.execute("INSERT INTO #{TABLE} (served_for_guest, guest_name) VALUES (TRUE, '  Anna  '), (TRUE, ''), (FALSE, 'Ignored')")

    ReplaceBrewGuestFieldsWithRecipient.new.backfill_recipient_columns(TABLE)
    rows = connection.select_all("SELECT recipient_kind, recipient_user_id, recipient_name FROM #{TABLE} ORDER BY id").to_a

    assert_equal [
      { "recipient_kind" => "guest", "recipient_user_id" => nil, "recipient_name" => "Anna" },
      { "recipient_kind" => "guest", "recipient_user_id" => nil, "recipient_name" => nil },
      { "recipient_kind" => "self", "recipient_user_id" => nil, "recipient_name" => nil }
    ], rows
  end
end
