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

ActiveRecord::Schema[8.0].define(version: 2025_12_31_090300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attendance_changes", force: :cascade do |t|
    t.bigint "attendance_record_id"
    t.bigint "user_id"
    t.bigint "school_class_id"
    t.date "date", null: false
    t.string "previous_status"
    t.string "new_status", null: false
    t.text "reason"
    t.bigint "modified_by_id"
    t.string "source", default: "manual", null: false
    t.string "ip"
    t.string "user_agent"
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attendance_record_id"], name: "index_attendance_changes_on_attendance_record_id"
    t.index ["changed_at"], name: "index_attendance_changes_on_changed_at"
    t.index ["modified_by_id"], name: "index_attendance_changes_on_modified_by_id"
    t.index ["school_class_id"], name: "index_attendance_changes_on_school_class_id"
    t.index ["user_id"], name: "index_attendance_changes_on_user_id"
  end

  create_table "attendance_policies", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.integer "late_after_minutes", default: 20, null: false
    t.integer "close_after_minutes", default: 20, null: false
    t.boolean "allow_early_checkin", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "allowed_ip_ranges"
    t.text "allowed_user_agent_keywords"
    t.integer "max_scans_per_minute", default: 10, null: false
    t.integer "minimum_attendance_rate", default: 80, null: false
    t.integer "warning_absent_count", default: 3, null: false
    t.integer "warning_rate_percent", default: 70, null: false
    t.index ["school_class_id"], name: "index_attendance_policies_on_school_class_id", unique: true
  end

  create_table "attendance_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "school_class_id", null: false
    t.date "date", null: false
    t.string "status", null: false
    t.datetime "timestamp", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.jsonb "location", default: {}
    t.string "verification_method", null: false
    t.bigint "modified_by_id"
    t.datetime "modified_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "class_session_id"
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.integer "duration_minutes"
    t.index ["class_session_id"], name: "index_attendance_records_on_class_session_id"
    t.index ["modified_by_id"], name: "index_attendance_records_on_modified_by_id"
    t.index ["school_class_id"], name: "index_attendance_records_on_school_class_id"
    t.index ["user_id", "school_class_id", "date"], name: "index_attendance_records_unique_day", unique: true
    t.index ["user_id"], name: "index_attendance_records_on_user_id"
  end

  create_table "attendance_requests", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "school_class_id", null: false
    t.bigint "class_session_id"
    t.date "date", null: false
    t.string "request_type", null: false
    t.string "status", default: "pending", null: false
    t.text "reason"
    t.datetime "submitted_at", null: false
    t.bigint "processed_by_id"
    t.datetime "processed_at"
    t.text "decision_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["class_session_id"], name: "index_attendance_requests_on_class_session_id"
    t.index ["processed_by_id"], name: "index_attendance_requests_on_processed_by_id"
    t.index ["school_class_id", "date"], name: "index_attendance_requests_on_school_class_id_and_date"
    t.index ["school_class_id"], name: "index_attendance_requests_on_school_class_id"
    t.index ["status"], name: "index_attendance_requests_on_status"
    t.index ["user_id", "date"], name: "index_attendance_requests_on_user_id_and_date"
    t.index ["user_id"], name: "index_attendance_requests_on_user_id"
  end

  create_table "class_session_overrides", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.date "date", null: false
    t.string "start_time"
    t.string "end_time"
    t.string "status", default: "regular", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_class_id", "date"], name: "index_class_session_overrides_on_school_class_id_and_date", unique: true
    t.index ["school_class_id"], name: "index_class_session_overrides_on_school_class_id"
    t.index ["status"], name: "index_class_session_overrides_on_status"
  end

  create_table "class_sessions", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.date "date", null: false
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "status", default: "regular", null: false
    t.datetime "locked_at"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_class_sessions_on_date"
    t.index ["school_class_id", "date"], name: "index_class_sessions_on_school_class_id_and_date", unique: true
    t.index ["school_class_id"], name: "index_class_sessions_on_school_class_id"
    t.index ["status"], name: "index_class_sessions_on_status"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.bigint "student_id", null: false
    t.datetime "enrolled_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_class_id", "student_id"], name: "index_enrollments_on_school_class_id_and_student_id", unique: true
    t.index ["school_class_id"], name: "index_enrollments_on_school_class_id"
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", default: "info", null: false
    t.string "title", null: false
    t.text "body"
    t.string "action_path"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
  end

  create_table "qr_scan_events", force: :cascade do |t|
    t.bigint "qr_session_id"
    t.bigint "user_id"
    t.bigint "school_class_id"
    t.string "status", null: false
    t.string "token_digest", null: false
    t.string "ip"
    t.string "user_agent"
    t.datetime "scanned_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attendance_status"
    t.index ["attendance_status"], name: "index_qr_scan_events_on_attendance_status"
    t.index ["qr_session_id"], name: "index_qr_scan_events_on_qr_session_id"
    t.index ["school_class_id"], name: "index_qr_scan_events_on_school_class_id"
    t.index ["status"], name: "index_qr_scan_events_on_status"
    t.index ["token_digest"], name: "index_qr_scan_events_on_token_digest"
    t.index ["user_id"], name: "index_qr_scan_events_on_user_id"
  end

  create_table "qr_sessions", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.bigint "teacher_id", null: false
    t.date "attendance_date", null: false
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_qr_sessions_on_expires_at"
    t.index ["school_class_id", "attendance_date"], name: "index_qr_sessions_on_school_class_id_and_attendance_date"
    t.index ["school_class_id"], name: "index_qr_sessions_on_school_class_id"
    t.index ["teacher_id"], name: "index_qr_sessions_on_teacher_id"
  end

  create_table "school_classes", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "teacher_id", null: false
    t.string "room", null: false
    t.string "subject", null: false
    t.string "semester", null: false
    t.integer "year", null: false
    t.integer "capacity", default: 40, null: false
    t.text "description"
    t.jsonb "schedule", default: {}, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_school_classes_on_teacher_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "role", null: false
    t.string "student_id"
    t.string "profile_image"
    t.jsonb "settings", default: {"theme"=>"light", "language"=>"ja", "notifications"=>{"push"=>false, "email"=>true}}, null: false
    t.string "password_digest", null: false
    t.datetime "last_login"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["student_id"], name: "index_users_on_student_id", unique: true
  end

  add_foreign_key "attendance_changes", "attendance_records"
  add_foreign_key "attendance_changes", "school_classes"
  add_foreign_key "attendance_changes", "users"
  add_foreign_key "attendance_changes", "users", column: "modified_by_id"
  add_foreign_key "attendance_policies", "school_classes"
  add_foreign_key "attendance_records", "class_sessions"
  add_foreign_key "attendance_records", "school_classes"
  add_foreign_key "attendance_records", "users"
  add_foreign_key "attendance_records", "users", column: "modified_by_id"
  add_foreign_key "attendance_requests", "class_sessions"
  add_foreign_key "attendance_requests", "school_classes"
  add_foreign_key "attendance_requests", "users"
  add_foreign_key "attendance_requests", "users", column: "processed_by_id"
  add_foreign_key "class_session_overrides", "school_classes"
  add_foreign_key "class_sessions", "school_classes"
  add_foreign_key "enrollments", "school_classes"
  add_foreign_key "enrollments", "users", column: "student_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "qr_scan_events", "qr_sessions"
  add_foreign_key "qr_scan_events", "school_classes"
  add_foreign_key "qr_scan_events", "users"
  add_foreign_key "qr_sessions", "school_classes"
  add_foreign_key "qr_sessions", "users", column: "teacher_id"
  add_foreign_key "school_classes", "users", column: "teacher_id"
end
