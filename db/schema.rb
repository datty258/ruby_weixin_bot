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

ActiveRecord::Schema.define(version: 20160906055230) do

  create_table "bots", force: :cascade do |t|
    t.string   "uin",              limit: 255
    t.string   "name",             limit: 255
    t.string   "bash_url",         limit: 255
    t.text     "cookies",          limit: 65535
    t.string   "synckey_text",     limit: 255
    t.string   "base_request",     limit: 255
    t.text     "synckey",          limit: 65535
    t.string   "ticket",           limit: 255
    t.integer  "is_logout",        limit: 4
    t.integer  "is_check",         limit: 4
    t.text     "user_information", limit: 65535
    t.string   "sync_host",        limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "publics", force: :cascade do |t|
    t.string   "user_name",    limit: 255
    t.string   "nick_name",    limit: 255
    t.string   "img_url",      limit: 255
    t.integer  "sex",          limit: 4
    t.integer  "member_count", limit: 4
    t.string   "alias",        limit: 255
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                limit: 255
    t.string   "name",                 limit: 255
    t.string   "phone",                limit: 255
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.string   "authentication_token", limit: 255
    t.string   "password",             limit: 255
    t.string   "password_digest",      limit: 255
  end

end
