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

ActiveRecord::Schema[8.1].define(version: 2026_08_17_060100) do
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

  create_table "dictionary_link_deferrals", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "link_name", limit: 32, null: false
    t.string "owner_entity_type", limit: 32, null: false
    t.string "owner_uuid", limit: 36, null: false
    t.string "target_code", limit: 32, null: false
    t.index ["owner_uuid", "link_name", "target_code"], name: "idx_link_deferrals_unique", unique: true
    t.index ["target_code"], name: "index_dictionary_link_deferrals_on_target_code"
  end

  create_table "dictionary_status_changes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "actor"
    t.datetime "created_at", null: false
    t.string "entity_type", limit: 32, null: false
    t.string "entity_uuid", limit: 36, null: false
    t.string "from_status", limit: 12
    t.string "national_code", limit: 32, null: false
    t.string "reason"
    t.bigint "revision"
    t.string "to_status", limit: 12, null: false
    t.index ["created_at"], name: "index_dictionary_status_changes_on_created_at"
    t.index ["entity_type", "to_status"], name: "index_dictionary_status_changes_on_entity_type_and_to_status"
    t.index ["entity_uuid"], name: "index_dictionary_status_changes_on_entity_uuid"
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

  create_table "inbound_deliveries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inbound_event_id", null: false
    t.string "node_code", limit: 24, null: false
    t.bigint "revision", null: false
    t.index ["inbound_event_id"], name: "index_inbound_deliveries_on_inbound_event_id"
    t.index ["node_code", "inbound_event_id"], name: "index_inbound_deliveries_on_node_and_event", unique: true
    t.index ["node_code", "revision"], name: "index_inbound_deliveries_on_node_code_and_revision"
  end

  create_table "inbound_events", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "aggregate_uuid", limit: 36, null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.string "error_code", limit: 40
    t.string "error_message", limit: 1000
    t.string "event_uuid", limit: 36, null: false
    t.string "node_code", limit: 24, null: false
    t.datetime "occurred_at", null: false
    t.text "payload", null: false
    t.datetime "received_at", null: false
    t.bigint "sequence", null: false
    t.string "status", limit: 12, default: "pending", null: false
    t.string "type", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["event_uuid"], name: "index_inbound_events_on_event_uuid", unique: true
    t.index ["node_code", "aggregate_uuid", "sequence"], name: "index_inbound_events_on_stream", unique: true
    t.index ["status", "received_at"], name: "index_inbound_events_on_status_and_received_at"
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

  create_table "nodes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dictionary_cursor", default: 0, null: false
    t.string "last_error", limit: 1000
    t.datetime "last_seen_at"
    t.string "name"
    t.string "node_code", limit: 24, null: false
    t.integer "outbox_failing", default: 0, null: false
    t.integer "outbox_pending", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "version", limit: 32
    t.index ["last_seen_at"], name: "index_nodes_on_last_seen_at"
    t.index ["node_code"], name: "index_nodes_on_node_code", unique: true
  end

  create_table "order_tests", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "method_of_testing", limit: 64
    t.bigint "order_id", null: false
    t.string "status", limit: 24, default: "pending", null: false
    t.bigint "test_panel_id"
    t.bigint "test_type_id", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["order_id", "test_type_id"], name: "index_order_tests_on_order_id_and_test_type_id"
    t.index ["order_id"], name: "index_order_tests_on_order_id"
    t.index ["status"], name: "index_order_tests_on_status"
    t.index ["test_panel_id"], name: "index_order_tests_on_test_panel_id"
    t.index ["test_type_id"], name: "index_order_tests_on_test_type_id"
    t.index ["uuid"], name: "index_order_tests_on_uuid", unique: true
  end

  create_table "orders", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "claimed_at"
    t.string "claimed_by_lab_code", limit: 24
    t.text "clinical_history"
    t.datetime "collected_at"
    t.datetime "created_at", null: false
    t.string "lab_code", limit: 32
    t.string "order_location"
    t.bigint "patient_id", null: false
    t.string "priority", limit: 12, default: "routine", null: false
    t.string "receiving_lab_code", limit: 24, null: false
    t.bigint "rejection_reason_id"
    t.string "requested_by"
    t.bigint "revision", default: 0, null: false
    t.string "sending_facility_code", limit: 16, null: false
    t.bigint "source_client_id"
    t.string "source_system", limit: 16
    t.bigint "specimen_type_id"
    t.string "status", limit: 24, default: "requested", null: false
    t.string "tracking_number", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["patient_id"], name: "index_orders_on_patient_id"
    t.index ["receiving_lab_code", "revision"], name: "index_orders_on_receiving_lab_code_and_revision"
    t.index ["receiving_lab_code", "status"], name: "index_orders_on_receiving_lab_code_and_status"
    t.index ["rejection_reason_id"], name: "index_orders_on_rejection_reason_id"
    t.index ["revision"], name: "index_orders_on_revision"
    t.index ["sending_facility_code", "created_at"], name: "index_orders_on_sending_facility_code_and_created_at"
    t.index ["source_client_id"], name: "index_orders_on_source_client_id"
    t.index ["specimen_type_id"], name: "index_orders_on_specimen_type_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["tracking_number"], name: "index_orders_on_tracking_number", unique: true
    t.index ["uuid"], name: "index_orders_on_uuid", unique: true
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

  create_table "patients", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.date "birthdate"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "national_id", limit: 32
    t.string "phone", limit: 32
    t.string "sex", limit: 8, default: "Unknown", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["name"], name: "index_patients_on_name"
    t.index ["national_id"], name: "index_patients_on_national_id", unique: true
    t.index ["uuid"], name: "index_patients_on_uuid", unique: true
  end

  create_table "referrals", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "courier"
    t.datetime "created_at", null: false
    t.datetime "dispatched_at", null: false
    t.string "from_facility_code", limit: 16, null: false
    t.string "from_lab_code", limit: 24
    t.bigint "order_id", null: false
    t.datetime "received_at"
    t.datetime "rejected_at"
    t.bigint "rejection_reason_id"
    t.text "remarks"
    t.string "state", limit: 12, default: "dispatched", null: false
    t.string "to_facility_code", limit: 16, null: false
    t.string "to_lab_code", limit: 24, null: false
    t.string "tracking_number", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["from_facility_code", "dispatched_at"], name: "index_referrals_on_from_facility_code_and_dispatched_at"
    t.index ["order_id"], name: "index_referrals_on_order_id"
    t.index ["rejection_reason_id"], name: "index_referrals_on_rejection_reason_id"
    t.index ["to_facility_code", "state"], name: "index_referrals_on_to_facility_code_and_state"
    t.index ["tracking_number"], name: "index_referrals_on_tracking_number"
    t.index ["uuid"], name: "index_referrals_on_uuid", unique: true
  end

  create_table "rejection_reasons", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
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
    t.index ["national_code"], name: "index_rejection_reasons_on_national_code", unique: true
    t.index ["revision"], name: "index_rejection_reasons_on_revision"
    t.index ["status", "revision"], name: "index_rejection_reasons_on_status_and_revision"
    t.index ["uuid"], name: "index_rejection_reasons_on_uuid", unique: true
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

  create_table "status_events", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "actor"
    t.datetime "created_at", null: false
    t.string "entity_type", limit: 24, null: false
    t.string "entity_uuid", limit: 36, null: false
    t.string "from_status", limit: 24
    t.string "reason"
    t.string "to_status", limit: 24, null: false
    t.string "tracking_number", limit: 32, null: false
    t.string "uuid", limit: 36, null: false
    t.index ["entity_type", "to_status"], name: "index_status_events_on_entity_type_and_to_status"
    t.index ["entity_uuid", "created_at"], name: "index_status_events_on_entity_uuid_and_created_at"
    t.index ["tracking_number", "created_at"], name: "index_status_events_on_tracking_number_and_created_at"
    t.index ["uuid"], name: "index_status_events_on_uuid", unique: true
  end

  create_table "sync_cursors", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "last_attempted_at"
    t.string "last_error", limit: 1000
    t.datetime "last_synced_at"
    t.string "name", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.bigint "value", default: 0, null: false
    t.index ["name"], name: "index_sync_cursors_on_name", unique: true
  end

  create_table "sync_outbox", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "aggregate_uuid", limit: 36, null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "event_uuid", limit: 36, null: false
    t.string "last_error", limit: 1000
    t.datetime "next_attempt_at"
    t.datetime "occurred_at", null: false
    t.text "payload", null: false
    t.bigint "sequence", null: false
    t.string "type", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["aggregate_uuid", "sequence"], name: "index_sync_outbox_on_aggregate_uuid_and_sequence", unique: true
    t.index ["delivered_at", "next_attempt_at"], name: "index_sync_outbox_on_delivered_at_and_next_attempt_at"
    t.index ["event_uuid"], name: "index_sync_outbox_on_event_uuid", unique: true
    t.index ["type"], name: "index_sync_outbox_on_type"
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

  create_table "test_results", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.datetime "created_at", null: false
    t.bigint "indicator_id", null: false
    t.bigint "order_test_id", null: false
    t.datetime "recorded_at", null: false
    t.string "recorded_by"
    t.string "replaced_by_uuid", limit: 36
    t.bigint "revision", default: 0, null: false
    t.string "unit", limit: 32
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.text "value"
    t.index ["indicator_id"], name: "index_test_results_on_indicator_id"
    t.index ["order_test_id", "indicator_id"], name: "index_test_results_on_order_test_id_and_indicator_id"
    t.index ["order_test_id"], name: "index_test_results_on_order_test_id"
    t.index ["recorded_at"], name: "index_test_results_on_recorded_at"
    t.index ["replaced_by_uuid"], name: "index_test_results_on_replaced_by_uuid"
    t.index ["revision"], name: "index_test_results_on_revision"
    t.index ["uuid"], name: "index_test_results_on_uuid", unique: true
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
  add_foreign_key "inbound_deliveries", "inbound_events"
  add_foreign_key "indicator_ranges", "indicators"
  add_foreign_key "order_tests", "orders"
  add_foreign_key "order_tests", "test_panels"
  add_foreign_key "order_tests", "test_types"
  add_foreign_key "orders", "api_clients", column: "source_client_id"
  add_foreign_key "orders", "patients"
  add_foreign_key "orders", "rejection_reasons"
  add_foreign_key "orders", "specimen_types"
  add_foreign_key "organism_drugs", "drugs"
  add_foreign_key "organism_drugs", "organisms"
  add_foreign_key "referrals", "orders"
  add_foreign_key "referrals", "rejection_reasons"
  add_foreign_key "request_audits", "api_clients"
  add_foreign_key "request_audits", "api_keys"
  add_foreign_key "test_panel_test_types", "test_panels"
  add_foreign_key "test_panel_test_types", "test_types"
  add_foreign_key "test_results", "indicators"
  add_foreign_key "test_results", "order_tests"
  add_foreign_key "test_type_indicators", "indicators"
  add_foreign_key "test_type_indicators", "test_types"
  add_foreign_key "test_type_organisms", "organisms"
  add_foreign_key "test_type_organisms", "test_types"
  add_foreign_key "test_type_specimen_types", "specimen_types"
  add_foreign_key "test_type_specimen_types", "test_types"
  add_foreign_key "test_types", "departments"
end
