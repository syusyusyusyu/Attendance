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

ActiveRecord::Schema[8.0].define(version: 2025_12_30_133100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attendance_policies", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.integer "late_after_minutes", default: 10, null: false
    t.integer "close_after_minutes", default: 90, null: false
    t.boolean "allow_early_checkin", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["modified_by_id"], name: "index_attendance_records_on_modified_by_id"
    t.index ["school_class_id"], name: "index_attendance_records_on_school_class_id"
    t.index ["user_id", "school_class_id", "date"], name: "index_attendance_records_unique_day", unique: true
    t.index ["user_id"], name: "index_attendance_records_on_user_id"
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

  add_foreign_key "attendance_policies", "school_classes"
  add_foreign_key "attendance_records", "school_classes"
  add_foreign_key "attendance_records", "users"
  add_foreign_key "attendance_records", "users", column: "modified_by_id"
  add_foreign_key "enrollments", "school_classes"
  add_foreign_key "enrollments", "users", column: "student_id"
  add_foreign_key "qr_scan_events", "qr_sessions"
  add_foreign_key "qr_scan_events", "school_classes"
  add_foreign_key "qr_scan_events", "users"
  add_foreign_key "qr_sessions", "school_classes"
  add_foreign_key "qr_sessions", "users", column: "teacher_id"
  add_foreign_key "school_classes", "users", column: "teacher_id"
end
