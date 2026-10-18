class AddRightTurnLaneToLinks < ActiveRecord::Migration[8.1]
  def change
    # Cells at the end of the link with a separate lane for cars turning right (0 = none)
    add_column :links, :right_turn_lane, :integer, null: false, default: 0
  end
end
