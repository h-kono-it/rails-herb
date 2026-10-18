class AddSignalPlanToNodes < ActiveRecord::Migration[8.1]
  def change
    # Fixed-time plan for a signalized junction: cycle length in steps, the
    # horizontal phase's share of the green time in percent, and how many
    # steps into its cycle the junction is at step 0
    change_table :nodes, bulk: true do |t|
      t.integer :cycle, null: false, default: 40
      t.integer :split, null: false, default: 50
      t.integer :offset, null: false, default: 0
    end
  end
end
