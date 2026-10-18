module NetworksHelper
  # Cars drive this far left of the road's centre line, in cells (traffic keeps left)
  LANE_OFFSET = 0.5
  # Signal heads sit this far back from the junction and out to the kerb, in cells
  SIGNAL_SETBACK = 1.5
  SIGNAL_OFFSET = 1.6

  def map_percent(value)
    (value * 100.0 / Network::SIZE).round(3)
  end

  # Inline style for a road between two nodes, drawn as a bar rotated around
  # its start.
  def road_style(from, to)
    length = Math.hypot(to.x - from.x, to.y - from.y)
    angle = Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math::PI
    "left: #{map_percent(from.x)}%; top: #{map_percent(from.y - 1)}%; width: #{map_percent(length)}%; height: #{map_percent(2)}%; rotate: #{angle.round(2)}deg"
  end

  def point_style(x, y)
    "left: #{map_percent(x)}%; top: #{map_percent(y)}%"
  end

  # Where a car is drawn: the middle of its cell, shifted to the left lane.
  def car_point(simulation, car)
    from, to, ux, uy = link_geometry(simulation.graph, simulation.graph.links.fetch(car.link))
    along = (car.position + 0.5) / simulation.graph.length(car.link) * Math.hypot(to.x - from.x, to.y - from.y)
    left_x, left_y = uy, -ux
    [ from.x + ux * along + left_x * LANE_OFFSET, from.y + uy * along + left_y * LANE_OFFSET ]
  end

  # Where the signal head for a link into a junction is drawn.
  def signal_point(graph, link)
    _from, to, ux, uy = link_geometry(graph, link)
    left_x, left_y = uy, -ux
    [ to.x - ux * SIGNAL_SETBACK + left_x * SIGNAL_OFFSET, to.y - uy * SIGNAL_SETBACK + left_y * SIGNAL_OFFSET ]
  end

  # Where a dead end sits on the map, e.g. "西端 (0, 30)".
  def dead_end_label(node)
    side =
      if node.x.zero? then "西端"
      elsif node.x == Network::SIZE then "東端"
      elsif node.y.zero? then "北端"
      elsif node.y == Network::SIZE then "南端"
      else "端"
      end
    "#{side} (#{node.x}, #{node.y})"
  end

  TURN_LABELS = { left: "左折", straight: "直進", right: "右折" }.freeze
  APPROACHES = %w[北から 東から 南から 西から].freeze

  def junction_label(node)
    "(#{node.x}, #{node.y})"
  end

  # The junction picked in the page, or the first one.
  def selected_junction(junctions, id)
    junctions.find { |node| node.id == id } || junctions.first
  end

  # Which side a link comes into its junction from, e.g. "西から".
  def approach_label(graph, link)
    from, to = graph.nodes.values_at(link.from, link.to)
    dx, dy = to.x - from.x, to.y - from.y
    if dx.abs >= dy.abs
      dx.positive? ? "西から" : "東から"
    else
      dy.positive? ? "北から" : "南から"
    end
  end

  # The turns the junction at the end of a link lets its cars make.
  def offered_turns(graph, link)
    graph.outgoing(link.to).reject { |other| other.to == link.from }.map { |other| graph.turn(link.id, other.id) }.uniq
  end

  # A turn's share of the link's weights, in percent, among the offered turns.
  def turn_share(link, turn, offered)
    total = offered.sum { |other| link.turn_weights[other] }
    return (100.0 / offered.size).round if total.zero?

    (link.turn_weights[turn] * 100.0 / total).round
  end

  # The share of cars that actually went that way so far, in percent.
  def actual_share(simulation, link, turn)
    total = Link::TURNS.sum { |other| simulation.turn_count(link.id, other) }
    return if total.zero?

    (simulation.turn_count(link.id, turn) * 100.0 / total).round
  end

  # Each two-way road once, as [from, to] node pairs.
  def roads(graph)
    graph.links.values.map { |link| [ link.from, link.to ].sort }.uniq.map { |ids| graph.nodes.values_at(*ids) }
  end

  private
    def link_geometry(graph, link)
      from, to = graph.nodes.values_at(link.from, link.to)
      length = Math.hypot(to.x - from.x, to.y - from.y)
      [ from, to, (to.x - from.x) / length, (to.y - from.y) / length ]
    end
end
