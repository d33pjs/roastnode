# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_26_110100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "beans", force: :cascade do |t|
    t.datetime "archived_at"
    t.decimal "bag_size_grams", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "data_import_id"
    t.string "import_source"
    t.string "import_source_id"
    t.string "name", null: false
    t.text "notes"
    t.date "opened_on"
    t.string "origin"
    t.string "process"
    t.integer "purchase_price_cents"
    t.string "purchase_source"
    t.string "purchase_url"
    t.date "purchased_on"
    t.integer "rating"
    t.jsonb "raw_import_data", default: {}, null: false
    t.decimal "remaining_grams", precision: 10, scale: 2, null: false
    t.date "roast_date"
    t.string "roast_level"
    t.string "roaster_name"
    t.text "tasting_notes"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["data_import_id"], name: "index_beans_on_data_import_id"
    t.index ["workspace_id", "archived_at"], name: "index_beans_on_workspace_id_and_archived_at"
    t.index ["workspace_id", "import_source", "import_source_id"], name: "idx_beans_import_identity", unique: true, where: "((import_source IS NOT NULL) AND (import_source_id IS NOT NULL))"
    t.index ["workspace_id"], name: "index_beans_on_workspace_id"
  end

  create_table "brew_preparation_tools", force: :cascade do |t|
    t.bigint "brew_id", null: false
    t.string "brew_method", default: "espresso", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.bigint "preparation_tool_id"
    t.string "tool_name", null: false
    t.datetime "updated_at", null: false
    t.index ["brew_id", "position"], name: "index_brew_preparation_tools_on_brew_id_and_position"
    t.index ["brew_id"], name: "index_brew_preparation_tools_on_brew_id"
    t.index ["preparation_tool_id"], name: "index_brew_preparation_tools_on_preparation_tool_id"
  end

  create_table "brews", force: :cascade do |t|
    t.bigint "bean_id", null: false
    t.decimal "bean_weight_grams", precision: 8, scale: 2, null: false
    t.decimal "beverage_grams", precision: 8, scale: 2
    t.decimal "brew_temperature_celsius", precision: 5, scale: 2
    t.boolean "channeling"
    t.datetime "created_at", null: false
    t.bigint "data_import_id"
    t.decimal "dose_grams", precision: 8, scale: 2
    t.integer "first_drip_seconds"
    t.string "grind_setting"
    t.bigint "grinder_id"
    t.decimal "ground_weight_grams", precision: 8, scale: 2
    t.string "import_source"
    t.string "import_source_id"
    t.bigint "machine_id"
    t.string "method", default: "espresso", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.integer "preinfusion_seconds"
    t.integer "rating"
    t.jsonb "raw_import_data", default: {}, null: false
    t.string "retention_marker", default: "unknown", null: false
    t.string "taste_balance", default: "unknown", null: false
    t.integer "total_time_seconds"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["bean_id"], name: "index_brews_on_bean_id"
    t.index ["data_import_id"], name: "index_brews_on_data_import_id"
    t.index ["grinder_id"], name: "index_brews_on_grinder_id"
    t.index ["machine_id"], name: "index_brews_on_machine_id"
    t.index ["user_id"], name: "index_brews_on_user_id"
    t.index ["workspace_id", "import_source", "import_source_id"], name: "idx_brews_import_identity", unique: true, where: "((import_source IS NOT NULL) AND (import_source_id IS NOT NULL))"
    t.index ["workspace_id", "occurred_at"], name: "index_brews_on_workspace_id_and_occurred_at"
    t.index ["workspace_id"], name: "index_brews_on_workspace_id"
  end

  create_table "data_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "source", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "warnings", default: [], null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_data_imports_on_user_id"
    t.index ["workspace_id", "source", "created_at"], name: "index_data_imports_on_workspace_id_and_source_and_created_at"
    t.index ["workspace_id"], name: "index_data_imports_on_workspace_id"
  end

  create_table "equipment", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "data_import_id"
    t.string "import_source"
    t.string "import_source_id"
    t.string "kind", null: false
    t.string "model"
    t.string "name", null: false
    t.text "notes"
    t.jsonb "raw_import_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["data_import_id"], name: "index_equipment_on_data_import_id"
    t.index ["workspace_id", "import_source", "import_source_id"], name: "idx_equipment_import_identity", unique: true, where: "((import_source IS NOT NULL) AND (import_source_id IS NOT NULL))"
    t.index ["workspace_id", "kind"], name: "index_equipment_on_workspace_id_and_kind"
    t.index ["workspace_id"], name: "index_equipment_on_workspace_id"
  end

  create_table "equipment_event_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "equipment_event_id", null: false
    t.bigint "equipment_id", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_event_id", "equipment_id"], name: "idx_on_equipment_event_id_equipment_id_22b5e78c10", unique: true
    t.index ["equipment_event_id"], name: "index_equipment_event_items_on_equipment_event_id"
    t.index ["equipment_id"], name: "index_equipment_event_items_on_equipment_id"
  end

  create_table "equipment_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "event_types", default: [], null: false, array: true
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_equipment_events_on_user_id"
    t.index ["workspace_id", "event_type"], name: "index_equipment_events_on_workspace_id_and_event_type"
    t.index ["workspace_id", "occurred_at"], name: "index_equipment_events_on_workspace_id_and_occurred_at"
    t.index ["workspace_id"], name: "index_equipment_events_on_workspace_id"
  end

  create_table "inventory_adjustments", force: :cascade do |t|
    t.bigint "bean_id", null: false
    t.bigint "brew_id"
    t.datetime "created_at", null: false
    t.decimal "delta_grams", precision: 10, scale: 2, null: false
    t.text "note"
    t.datetime "occurred_at", null: false
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["bean_id"], name: "index_inventory_adjustments_on_bean_id"
    t.index ["brew_id"], name: "index_inventory_adjustments_on_brew_id"
    t.index ["user_id"], name: "index_inventory_adjustments_on_user_id"
    t.index ["workspace_id", "occurred_at"], name: "index_inventory_adjustments_on_workspace_id_and_occurred_at"
    t.index ["workspace_id"], name: "index_inventory_adjustments_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "preparation_tools", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "brew_method", default: "espresso", null: false
    t.datetime "created_at", null: false
    t.bigint "data_import_id"
    t.string "import_source"
    t.string "import_source_id"
    t.string "name", null: false
    t.text "notes"
    t.jsonb "raw_import_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["data_import_id"], name: "index_preparation_tools_on_data_import_id"
    t.index ["workspace_id", "brew_method", "active"], name: "idx_on_workspace_id_brew_method_active_63d2fd7955"
    t.index ["workspace_id", "import_source", "import_source_id"], name: "idx_preparation_tools_import_identity", unique: true, where: "((import_source IS NOT NULL) AND (import_source_id IS NOT NULL))"
    t.index ["workspace_id"], name: "index_preparation_tools_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "active_workspace_id"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email_address", null: false
    t.boolean "instance_admin", default: false, null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["active_workspace_id"], name: "index_users_on_active_workspace_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspace_invites", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "accepted_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "email_address"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["accepted_by_id"], name: "index_workspace_invites_on_accepted_by_id"
    t.index ["created_by_id"], name: "index_workspace_invites_on_created_by_id"
    t.index ["token"], name: "index_workspace_invites_on_token", unique: true
    t.index ["workspace_id"], name: "index_workspace_invites_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_currency", default: "EUR", null: false
    t.string "kind", default: "household", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "beans", "data_imports"
  add_foreign_key "beans", "workspaces"
  add_foreign_key "brew_preparation_tools", "brews"
  add_foreign_key "brew_preparation_tools", "preparation_tools"
  add_foreign_key "brews", "beans"
  add_foreign_key "brews", "data_imports"
  add_foreign_key "brews", "equipment", column: "grinder_id"
  add_foreign_key "brews", "equipment", column: "machine_id"
  add_foreign_key "brews", "users"
  add_foreign_key "brews", "workspaces"
  add_foreign_key "data_imports", "users"
  add_foreign_key "data_imports", "workspaces"
  add_foreign_key "equipment", "data_imports"
  add_foreign_key "equipment", "workspaces"
  add_foreign_key "equipment_event_items", "equipment"
  add_foreign_key "equipment_event_items", "equipment_events"
  add_foreign_key "equipment_events", "users"
  add_foreign_key "equipment_events", "workspaces"
  add_foreign_key "inventory_adjustments", "beans"
  add_foreign_key "inventory_adjustments", "brews"
  add_foreign_key "inventory_adjustments", "users"
  add_foreign_key "inventory_adjustments", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "preparation_tools", "data_imports"
  add_foreign_key "preparation_tools", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "workspaces", column: "active_workspace_id"
  add_foreign_key "workspace_invites", "users", column: "accepted_by_id"
  add_foreign_key "workspace_invites", "users", column: "created_by_id"
  add_foreign_key "workspace_invites", "workspaces"
end
