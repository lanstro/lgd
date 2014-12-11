# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141210233214) do

  create_table "acts", force: true do |t|
    t.string   "title"
    t.date     "last_updated"
    t.string   "jurisdiction"
    t.text     "updating_acts"
    t.string   "subtitle"
    t.string   "regulations"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "act_type"
    t.integer  "year"
    t.integer  "number"
    t.boolean  "published"
    t.string   "comlawID"
    t.integer  "flags_count"
  end

  add_index "acts", ["year", "number"], name: "index_acts_on_year_and_number"

  create_table "annotations", force: true do |t|
    t.integer  "metadatum_id"
    t.integer  "container_id"
    t.string   "anchor"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "category"
  end

  add_index "annotations", ["anchor", "container_id", "metadatum_id", "position"], name: "annotation_uniqueness", unique: true

  create_table "comments", force: true do |t|
    t.string   "content"
    t.integer  "user_id"
    t.integer  "container_id"
    t.integer  "reputation"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ancestry"
    t.integer  "ancestry_depth"
    t.integer  "flags_count"
  end

  add_index "comments", ["ancestry"], name: "index_comments_on_ancestry"
  add_index "comments", ["container_id"], name: "index_comments_on_container_id"

  create_table "containers", force: true do |t|
    t.text     "number"
    t.date     "last_updated"
    t.text     "updating_acts"
    t.integer  "regulations"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "act_id"
    t.text     "content"
    t.integer  "level"
    t.string   "special_paragraph"
    t.integer  "position"
    t.string   "ancestry"
    t.integer  "ancestry_depth"
    t.text     "annotated_content"
    t.datetime "definition_parsed"
    t.datetime "references_parsed"
    t.datetime "annotation_parsed"
    t.boolean  "definition_zone"
    t.integer  "flags_count"
  end

  add_index "containers", ["act_id", "number"], name: "index_containers_on_act_id_and_number"
  add_index "containers", ["ancestry"], name: "index_containers_on_ancestry"
  add_index "containers", ["content", "act_id", "ancestry", "number", "position"], name: "container_uniqueness", unique: true

  create_table "flags", force: true do |t|
    t.string   "category"
    t.integer  "user_id"
    t.integer  "flaggable_id"
    t.string   "flaggable_type"
    t.string   "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "identities", force: true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "identities", ["user_id"], name: "index_identities_on_user_id"

  create_table "metadata", force: true do |t|
    t.integer  "scope_id"
    t.string   "scope_type"
    t.integer  "content_id"
    t.string   "content_type"
    t.text     "anchor"
    t.string   "category"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "universal_scope"
    t.integer  "flags_count"
  end

  add_index "metadata", ["anchor", "scope_id", "scope_type", "content_id", "content_type", "universal_scope", "category"], name: "metadata_uniqueness", unique: true
  add_index "metadata", ["content_id", "content_type"], name: "index_metadata_on_content_id_and_content_type"
  add_index "metadata", ["scope_id", "scope_type"], name: "index_metadata_on_scope_id_and_scope_type"

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        default: 0,  null: false
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.boolean  "admin"
    t.integer  "reputation"
    t.integer  "comments_total"
    t.string   "name"
    t.string   "organisation"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true

end
