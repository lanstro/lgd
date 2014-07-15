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

ActiveRecord::Schema.define(version: 20140714235018) do

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
  end

  add_index "acts", ["year", "number"], name: "index_acts_on_year_and_number"

  create_table "anchors", force: true do |t|
    t.string   "anchor_text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "container_id"
  end

  create_table "containers", force: true do |t|
    t.text     "number"
    t.date     "last_updated"
    t.text     "updating_acts"
    t.integer  "regulations"
    t.string   "container_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "act_id"
    t.integer  "parent_id"
    t.text     "content"
  end

  add_index "containers", ["act_id", "number"], name: "index_containers_on_act_id_and_number"
  add_index "containers", ["parent_id"], name: "index_containers_on_parent_id"

  create_table "metadata", force: true do |t|
    t.string   "meta_type"
    t.string   "external_link"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.boolean  "admin"
    t.integer  "reputation"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password_digest"
    t.string   "remember_token"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["remember_token"], name: "index_users_on_remember_token"

end
