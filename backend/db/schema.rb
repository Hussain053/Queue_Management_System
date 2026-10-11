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

ActiveRecord::Schema[8.1].define(version: 2026_10_12_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "queue_tokens", force: :cascade do |t|
    t.bigint "queue_id", null: false
    t.string "service_date", null: false
    t.integer "sequence_number", null: false
    t.string "token_number", null: false
    t.string "customer_name", null: false
    t.string "contact_number"
    t.string "public_lookup_token", null: false
    t.string "service_type", null: false
    t.string "status", default: "waiting", null: false
    t.datetime "joined_at", null: false
    t.datetime "called_at"
    t.datetime "service_started_at"
    t.datetime "completed_at"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "visit_requirements"
    t.index ["public_lookup_token"], name: "index_queue_tokens_on_public_lookup_token", unique: true
    t.index ["queue_id", "service_date", "sequence_number"], name: "idx_queue_token_daily_sequence", unique: true
    t.index ["queue_id", "service_date", "status", "joined_at"], name: "idx_on_queue_id_service_date_status_joined_at_1238d3f3d0"
    t.index ["queue_id"], name: "index_queue_tokens_on_queue_id"
    t.check_constraint "status::text = ANY (ARRAY['waiting'::character varying::text, 'serving'::character varying::text, 'completed'::character varying::text, 'skipped'::character varying::text, 'cancelled'::character varying::text])", name: "queue_tokens_valid_status"
  end

  create_table "queues", force: :cascade do |t|
    t.string "name", null: false
    t.string "service_type", null: false
    t.integer "average_service_duration_minutes", default: 10, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "average_service_duration_minutes > 0", name: "queues_duration_positive"
  end

  create_table "staff_sessions", force: :cascade do |t|
    t.bigint "staff_user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_staff_sessions_on_expires_at"
    t.index ["staff_user_id"], name: "index_staff_sessions_on_staff_user_id"
    t.index ["token_digest"], name: "index_staff_sessions_on_token_digest", unique: true
  end

  create_table "staff_users", force: :cascade do |t|
    t.string "username", null: false
    t.string "display_name", null: false
    t.string "role", null: false
    t.string "password_digest", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((username)::text)", name: "idx_staff_users_username_lower", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'doctor'::character varying, 'receptionist'::character varying]::text[])", name: "staff_users_valid_role"
  end

  add_foreign_key "queue_tokens", "queues"
  add_foreign_key "staff_sessions", "staff_users", on_delete: :cascade
end
