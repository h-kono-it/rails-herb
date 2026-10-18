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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_131325) do
  create_table "links", force: :cascade do |t|
    t.integer "network_id", null: false
    t.integer "from_node_id", null: false
    t.integer "to_node_id", null: false
    t.integer "speed_limit", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "left_weight", default: 20, null: false
    t.integer "straight_weight", default: 60, null: false
    t.integer "right_weight", default: 20, null: false
    t.index ["from_node_id", "to_node_id"], name: "index_links_on_from_node_id_and_to_node_id", unique: true
    t.index ["from_node_id"], name: "index_links_on_from_node_id"
    t.index ["network_id"], name: "index_links_on_network_id"
    t.index ["to_node_id"], name: "index_links_on_to_node_id"
  end

  create_table "networks", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nodes", force: :cascade do |t|
    t.integer "network_id", null: false
    t.integer "x", null: false
    t.integer "y", null: false
    t.boolean "signalized", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "inflow", default: 15, null: false
    t.index ["network_id", "x", "y"], name: "index_nodes_on_network_id_and_x_and_y", unique: true
    t.index ["network_id"], name: "index_nodes_on_network_id"
  end

  add_foreign_key "links", "networks"
  add_foreign_key "links", "nodes", column: "from_node_id"
  add_foreign_key "links", "nodes", column: "to_node_id"
  add_foreign_key "nodes", "networks"
end
