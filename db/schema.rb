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

ActiveRecord::Schema[7.1].define(version: 2025_08_19_081539) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author"
    t.string "publisher"
    t.string "published_date"
    t.text "description"
    t.string "isbn_10"
    t.string "isbn_13"
    t.string "image_url"
    t.string "google_books_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "purchase_reason"
    t.date "purchase_date"
    t.index ["author"], name: "index_books_on_author"
    t.index ["google_books_id"], name: "index_books_on_google_books_id", unique: true
    t.index ["isbn_10"], name: "index_books_on_isbn_10", unique: true
    t.index ["isbn_13"], name: "index_books_on_isbn_13", unique: true
    t.index ["title"], name: "index_books_on_title"
    t.index ["user_id", "title"], name: "index_books_on_user_id_and_title"
    t.index ["user_id"], name: "index_books_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id"
    t.string "notification_type", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_notifications_on_book_id"
    t.index ["notification_type", "sent_at"], name: "index_notifications_on_notification_type_and_sent_at"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["sent_at"], name: "index_notifications_on_sent_at"
    t.index ["user_id", "notification_type"], name: "index_notifications_on_user_id_and_notification_type"
    t.index ["user_id", "sent_at"], name: "index_notifications_on_user_id_and_sent_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "books", "users"
  add_foreign_key "notifications", "books"
  add_foreign_key "notifications", "users"
end
