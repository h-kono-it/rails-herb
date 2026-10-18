class Network < ApplicationRecord
  # Nodes sit on a SIZE x SIZE grid, one unit per cell
  SIZE = 60

  has_many :nodes, dependent: :destroy
  has_many :links, dependent: :destroy

  validates :name, presence: true

  # Adds a two-way road: one link in each direction.
  def connect(a, b, speed_limit: 5)
    links.create!(from_node: a, to_node: b, speed_limit:)
    links.create!(from_node: b, to_node: a, speed_limit:)
  end

  # Plain data for the simulator, so it never touches the database.
  def graph
    Simulation::Graph.new(
      nodes: nodes.map { |node| Simulation::Node.new(id: node.id, x: node.x, y: node.y, signalized: node.signalized, inflow: node.inflow) },
      links: links.map { |link| Simulation::Link.new(id: link.id, from: link.from_node_id, to: link.to_node_id, speed_limit: link.speed_limit, turn_weights: link.turn_weights) }
    )
  end
end
