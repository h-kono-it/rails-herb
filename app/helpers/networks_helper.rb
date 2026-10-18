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
