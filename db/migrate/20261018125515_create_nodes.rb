class CreateNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :nodes do |t|
      t.references :network, null: false, foreign_key: true
      t.integer :x, null: false
      t.integer :y, null: false
      t.boolean :signalized, null: false, default: false

      t.timestamps
    end
    add_index :nodes, [ :network_id, :x, :y ], unique: true
  end
end
