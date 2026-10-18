class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :network, null: false, foreign_key: true
      t.references :from_node, null: false, foreign_key: { to_table: :nodes }
      t.references :to_node, null: false, foreign_key: { to_table: :nodes }
      t.integer :speed_limit, null: false, default: 5

      t.timestamps
    end
    add_index :links, [ :from_node_id, :to_node_id ], unique: true
  end
end
