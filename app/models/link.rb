# One lane of a road, going from one node to another.
class Link < ApplicationRecord
  belongs_to :network
  belongs_to :from_node, class_name: "Node", inverse_of: :outgoing_links
  belongs_to :to_node, class_name: "Node", inverse_of: :incoming_links

  validates :speed_limit, numericality: { only_integer: true, in: 1..5 }
  validates :to_node, uniqueness: { scope: :from_node }
  validate :nodes_differ

  private
    def nodes_differ
      errors.add(:to_node, "must differ from the start node") if from_node_id == to_node_id
    end
end
