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

ActiveRecord::Schema[8.1].define(version: 2026_08_16_220300) do
  create_table "api_clients", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "facility_code"
    t.string "kind", null: false
    t.string "lab_code"
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["facility_code", "lab_code"], name: "index_api_clients_on_facility_code_and_lab_code"
    t.index ["kind"], name: "index_api_clients_on_kind"
    t.index ["uuid"], name: "index_api_clients_on_uuid", unique: true
  end

  create_table "api_keys", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "api_client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "issued_by"
    t.string "key_digest", limit: 64, null: false
    t.datetime "last_used_at"
    t.string "prefix", limit: 16, null: false
    t.datetime "revoked_at"
    t.text "scopes", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["api_client_id"], name: "index_api_keys_on_api_client_id"
    t.index ["prefix"], name: "index_api_keys_on_prefix", unique: true
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["uuid"], name: "index_api_keys_on_uuid", unique: true
  end

  create_table "idempotent_requests", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "api_client_id", null: false
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.string "idempotency_key", null: false
    t.string "request_digest", limit: 64, null: false
    t.text "response_body", null: false
    t.integer "response_status", null: false
    t.index ["api_client_id", "idempotency_key"], name: "idx_idempotent_on_client_and_key", unique: true
    t.index ["api_client_id"], name: "index_idempotent_requests_on_api_client_id"
    t.index ["created_at"], name: "index_idempotent_requests_on_created_at"
  end

  create_table "request_audits", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "api_client_id"
    t.bigint "api_key_id"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_code"
    t.string "ip", limit: 45
    t.string "path", null: false
    t.string "request_id", limit: 36
    t.string "request_method", limit: 10, null: false
    t.integer "status", null: false
    t.index ["api_client_id", "created_at"], name: "index_request_audits_on_api_client_id_and_created_at"
    t.index ["api_client_id"], name: "index_request_audits_on_api_client_id"
    t.index ["api_key_id"], name: "index_request_audits_on_api_key_id"
    t.index ["created_at"], name: "index_request_audits_on_created_at"
    t.index ["error_code"], name: "index_request_audits_on_error_code"
  end

  add_foreign_key "api_keys", "api_clients"
  add_foreign_key "idempotent_requests", "api_clients"
  add_foreign_key "request_audits", "api_clients"
  add_foreign_key "request_audits", "api_keys"
end
