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

ActiveRecord::Schema[7.2].define(version: 2017_02_14_100255) do
  create_table "addresses", force: :cascade do |t|
    t.integer "patient_info_id"
    t.string "address"
    t.index ["patient_info_id"], name: "index_addresses_on_patient_info_id"
  end

  create_table "health_records", force: :cascade do |t|
    t.integer "patient_info_id"
    t.string "data"
    t.index ["patient_info_id"], name: "index_health_records_on_patient_info_id"
  end

  create_table "patient_details", force: :cascade do |t|
    t.integer "patient_info_id"
    t.string "detail"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["patient_info_id"], name: "index_patient_details_on_patient_info_id"
  end

  create_table "patient_infos", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "public_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end
end
