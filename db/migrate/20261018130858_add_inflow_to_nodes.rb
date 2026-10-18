class AddInflowToNodes < ActiveRecord::Migration[8.1]
  def change
    # Cars per 100 steps entering the network here, when the node is a dead end
    add_column :nodes, :inflow, :integer, null: false, default: 15
  end
end
