# One lane of a road, going from one node to another.
class Link < ApplicationRecord
  belongs_to :network
  belongs_to :from_node, class_name: "Node", inverse_of: :outgoing_links
  belongs_to :to_node, class_name: "Node", inverse_of: :incoming_links

  TURNS = %i[left straight right].freeze

  validates :speed_limit, numericality: { only_integer: true, in: 1..5 }
  validates :left_weight, :straight_weight, :right_weight, numericality: { only_integer: true, in: 0..100 }
  # The simulation shortens a pocket that does not fit the link (Simulation::Graph#pocket_length)
  validates :right_turn_lane, numericality: { only_integer: true, in: 0..15 }
  validates :to_node, uniqueness: { scope: :from_node }
  validate :nodes_differ

  def turn_weights
    TURNS.index_with { |turn| public_send(:"#{turn}_weight") }
  end

  private
    def nodes_differ
      errors.add(:to_node, "must differ from the start node") if from_node_id == to_node_id
    end
end
