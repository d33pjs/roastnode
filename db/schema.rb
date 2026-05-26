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

ActiveRecord::Schema[8.1].define(version: 2026_05_25_214800) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "workspaces", column: "active_workspace_id"
  add_foreign_key "workspace_invites", "users", column: "accepted_by_id"
  add_foreign_key "workspace_invites", "users", column: "created_by_id"
  add_foreign_key "workspace_invites", "workspaces"
end
