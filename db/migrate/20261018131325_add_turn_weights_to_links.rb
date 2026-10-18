class AddTurnWeightsToLinks < ActiveRecord::Migration[8.1]
  def change
    # How cars arriving on this link split at the junction it leads into.
    # Relative weights, spread over the turns the junction actually allows.
    change_table :links, bulk: true do |t|
      t.integer :left_weight, null: false, default: 20
      t.integer :straight_weight, null: false, default: 60
      t.integer :right_weight, null: false, default: 20
    end
  end
end
