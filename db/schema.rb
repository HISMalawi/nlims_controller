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

ActiveRecord::Schema[8.1].define(version: 2026_08_16_230300) do
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
    t.text "scopes", size: :long, null: false, collation: "utf8mb4_bin"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["api_client_id"], name: "index_api_keys_on_api_client_id"
    t.index ["prefix"], name: "index_api_keys_on_prefix", unique: true
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["uuid"], name: "index_api_keys_on_uuid", unique: true
    t.check_constraint "json_valid(`scopes`)", name: "scopes"
  end

  create_table "departments", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["national_code"], name: "index_departments_on_national_code", unique: true
    t.index ["revision"], name: "index_departments_on_revision"
    t.index ["status", "revision"], name: "index_departments_on_status_and_revision"
    t.index ["uuid"], name: "index_departments_on_uuid", unique: true
  end

  create_table "drugs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["national_code"], name: "index_drugs_on_national_code", unique: true
    t.index ["revision"], name: "index_drugs_on_revision"
    t.index ["status", "revision"], name: "index_drugs_on_status_and_revision"
    t.index ["uuid"], name: "index_drugs_on_uuid", unique: true
  end

  create_table "external_mappings", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "api_client_id"
    t.datetime "created_at", null: false
    t.string "entity_type", limit: 32, null: false
    t.string "entity_uuid", limit: 36, null: false
    t.string "external_code", null: false
    t.string "external_name"
    t.string "system", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["api_client_id"], name: "index_external_mappings_on_api_client_id"
    t.index ["entity_uuid"], name: "index_external_mappings_on_entity_uuid"
    t.index ["system", "api_client_id", "entity_type", "external_code"], name: "idx_external_mappings_lookup", unique: true, length: { external_code: 100 }
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

  create_table "indicator_ranges", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "age_max"
    t.integer "age_min"
    t.datetime "created_at", null: false
    t.bigint "indicator_id", null: false
    t.string "interpretation"
    t.decimal "range_lower", precision: 16, scale: 4
    t.decimal "range_upper", precision: 16, scale: 4
    t.string "sex", limit: 8, default: "Both", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["indicator_id"], name: "index_indicator_ranges_on_indicator_id"
  end

  create_table "indicators", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.string "unit", limit: 32
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.string "value_type", limit: 20, default: "Free Text", null: false
    t.index ["national_code"], name: "index_indicators_on_national_code", unique: true
    t.index ["revision"], name: "index_indicators_on_revision"
    t.index ["status", "revision"], name: "index_indicators_on_status_and_revision"
    t.index ["uuid"], name: "index_indicators_on_uuid", unique: true
  end

  create_table "organism_drugs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "drug_id", null: false
    t.bigint "organism_id", null: false
    t.datetime "updated_at", null: false
    t.index ["drug_id"], name: "index_organism_drugs_on_drug_id"
    t.index ["organism_id", "drug_id"], name: "idx_organism_drug_unique", unique: true
    t.index ["organism_id"], name: "index_organism_drugs_on_organism_id"
  end

  create_table "organisms", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["national_code"], name: "index_organisms_on_national_code", unique: true
    t.index ["revision"], name: "index_organisms_on_revision"
    t.index ["status", "revision"], name: "index_organisms_on_status_and_revision"
    t.index ["uuid"], name: "index_organisms_on_uuid", unique: true
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

  create_table "sequences", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.bigint "value", default: 0, null: false
    t.index ["name"], name: "index_sequences_on_name", unique: true
  end

  create_table "specimen_types", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["national_code"], name: "index_specimen_types_on_national_code", unique: true
    t.index ["revision"], name: "index_specimen_types_on_revision"
    t.index ["status", "revision"], name: "index_specimen_types_on_status_and_revision"
    t.index ["uuid"], name: "index_specimen_types_on_uuid", unique: true
  end

  create_table "test_panel_test_types", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "test_panel_id", null: false
    t.bigint "test_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["test_panel_id", "test_type_id"], name: "idx_panel_tt_unique", unique: true
    t.index ["test_panel_id"], name: "index_test_panel_test_types_on_test_panel_id"
    t.index ["test_type_id"], name: "index_test_panel_test_types_on_test_type_id"
  end

  create_table "test_panels", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["national_code"], name: "index_test_panels_on_national_code", unique: true
    t.index ["revision"], name: "index_test_panels_on_revision"
    t.index ["status", "revision"], name: "index_test_panels_on_status_and_revision"
    t.index ["uuid"], name: "index_test_panels_on_uuid", unique: true
  end

  create_table "test_type_indicators", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "indicator_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "test_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["indicator_id"], name: "index_test_type_indicators_on_indicator_id"
    t.index ["test_type_id", "indicator_id"], name: "idx_tt_indicator_unique", unique: true
    t.index ["test_type_id"], name: "index_test_type_indicators_on_test_type_id"
  end

  create_table "test_type_organisms", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organism_id", null: false
    t.bigint "test_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organism_id"], name: "index_test_type_organisms_on_organism_id"
    t.index ["test_type_id", "organism_id"], name: "idx_tt_organism_unique", unique: true
    t.index ["test_type_id"], name: "index_test_type_organisms_on_test_type_id"
  end

  create_table "test_type_specimen_types", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "specimen_type_id", null: false
    t.bigint "test_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["specimen_type_id"], name: "index_test_type_specimen_types_on_specimen_type_id"
    t.index ["test_type_id", "specimen_type_id"], name: "idx_tt_specimen_unique", unique: true
    t.index ["test_type_id"], name: "index_test_type_specimen_types_on_test_type_id"
  end

  create_table "test_types", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "department_id"
    t.text "description"
    t.string "loinc_code", limit: 32
    t.string "moh_code", limit: 32
    t.string "name", null: false
    t.string "national_code", limit: 32, null: false
    t.string "performed_on_sex", limit: 8, default: "Both", null: false
    t.bigint "revision", default: 0, null: false
    t.string "short_name"
    t.string "status", limit: 12, default: "draft", null: false
    t.string "target_tat", limit: 32
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["department_id"], name: "index_test_types_on_department_id"
    t.index ["national_code"], name: "index_test_types_on_national_code", unique: true
    t.index ["revision"], name: "index_test_types_on_revision"
    t.index ["status", "revision"], name: "index_test_types_on_status_and_revision"
    t.index ["uuid"], name: "index_test_types_on_uuid", unique: true
  end

  add_foreign_key "api_keys", "api_clients"
  add_foreign_key "external_mappings", "api_clients"
  add_foreign_key "idempotent_requests", "api_clients"
  add_foreign_key "indicator_ranges", "indicators"
  add_foreign_key "organism_drugs", "drugs"
  add_foreign_key "organism_drugs", "organisms"
  add_foreign_key "request_audits", "api_clients"
  add_foreign_key "request_audits", "api_keys"
  add_foreign_key "test_panel_test_types", "test_panels"
  add_foreign_key "test_panel_test_types", "test_types"
  add_foreign_key "test_type_indicators", "indicators"
  add_foreign_key "test_type_indicators", "test_types"
  add_foreign_key "test_type_organisms", "organisms"
  add_foreign_key "test_type_organisms", "test_types"
  add_foreign_key "test_type_specimen_types", "specimen_types"
  add_foreign_key "test_type_specimen_types", "test_types"
  add_foreign_key "test_types", "departments"
end
