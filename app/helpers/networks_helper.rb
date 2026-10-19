module NetworksHelper
  # Cars drive this far left of the road's centre line, in cells (traffic keeps left)
  LANE_OFFSET = 0.5
  # Where a right-turn pocket starts, the main lane moves one cell further
  # left and the pocket takes its place next to the oncoming lane
  POCKET_SHIFT = 1.0
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

  # Where a car is drawn: the middle of its cell, shifted to the left lane,
  # or one lane further left where its link has a pocket and it is not in it.
  def car_point(simulation, car)
    graph = simulation.graph
    from, to, ux, uy = link_geometry(graph, graph.links.fetch(car.link))
    along = (car.position + 0.5) / graph.length(car.link) * Math.hypot(to.x - from.x, to.y - from.y)
    beside_pocket = !car.pocket && car.position >= graph.pocket_start(car.link)
    offset = LANE_OFFSET + (beside_pocket ? POCKET_SHIFT : 0)
    left_x, left_y = uy, -ux
    [ from.x + ux * along + left_x * offset, from.y + uy * along + left_y * offset ]
  end

  # Inline style for the extra lane width along a link's right-turn pocket:
  # a one-cell strip on the left edge of the road, from the pocket start to
  # the junction.
  def pocket_style(graph, link)
    from, to, ux, uy = link_geometry(graph, link)
    distance = Math.hypot(to.x - from.x, to.y - from.y)
    start = graph.pocket_start(link.id).fdiv(graph.length(link.id)) * distance
    centre = 1 + POCKET_SHIFT / 2 # just outside the two-cell road
    x = from.x + ux * start + uy * centre
    y = from.y + uy * start - ux * centre
    angle = Math.atan2(uy, ux) * 180 / Math::PI
    "left: #{map_percent(x)}%; top: #{map_percent(y - POCKET_SHIFT / 2)}%; width: #{map_percent(distance - start)}%; height: #{map_percent(POCKET_SHIFT)}%; rotate: #{angle.round(2)}deg"
  end

  # Where the signal head for a link into a junction is drawn, clear of the
  # extra lane width of a pocket.
  def signal_point(graph, link)
    _from, to, ux, uy = link_geometry(graph, link)
    offset = SIGNAL_OFFSET + (graph.pocket_length(link.id).positive? ? POCKET_SHIFT : 0)
    left_x, left_y = uy, -ux
    [ to.x - ux * SIGNAL_SETBACK + left_x * offset, to.y - uy * SIGNAL_SETBACK + left_y * offset ]
  end

  SIDES = { west: "西", east: "東", north: "北", south: "南" }.freeze

  # Short names used on the map and in every table: junctions are A, B, C…
  # in reading order, dead ends are named after the edge they sit on (西, or
  # 西1, 西2… when an edge has several).
  def node_names(graph)
    junctions = graph.nodes.values.reject { |node| graph.dead_end?(node.id) }.sort_by { |node| [ node.y, node.x ] }
    names = junctions.each_with_index.to_h { |node, index| [ node.id, junction_letter(index) ] }

    dead_ends = graph.nodes.values.select { |node| graph.dead_end?(node.id) }
    dead_ends.group_by { |node| edge_of(node) }.each do |edge, nodes|
      nodes.sort_by { |node| [ node.x, node.y ] }.each_with_index do |node, index|
        names[node.id] = nodes.one? ? SIDES.fetch(edge, "端") : "#{SIDES.fetch(edge, "端")}#{index + 1}"
      end
    end
    names
  end

  # Dead ends clockwise from the north, then along each edge.
  def dead_end_order(node)
    [ %i[north east south west].index(edge_of(node)) || SIDES.size, node.x, node.y ]
  end

  # Where a node's name sits on the map: junction names up and to the left of
  # the crossing, dead end names just inside the edge.
  def name_point(node)
    case edge_of(node)
    when :west then [ 2, node.y - 2.6 ]
    when :east then [ Network::SIZE - 2, node.y + 2.6 ]
    when :north then [ node.x + 2.6, 2 ]
    when :south then [ node.x - 2.6, Network::SIZE - 2 ]
    else [ node.x - 3, node.y - 3 ]
    end
  end

  TURN_LABELS = { left: "左折", straight: "直進", right: "右折" }.freeze
  APPROACHES = %w[北から 東から 南から 西から].freeze

  # Heading for the junction picked in the page, e.g. "交差点 A".
  def junction_heading(graph, id)
    junctions = graph.nodes.values.reject { |node| graph.dead_end?(node.id) }.sort_by { |node| [ node.y, node.x ] }
    node = selected_junction(junctions, id)
    "交差点 #{node_names(graph)[node.id]}" if node
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
  # Settings changed mid-run apply from that step on; going back to the
  # start replays with them from step 0.
  def configured_note(simulation)
    return unless simulation.configured_at

    "ステップ #{number_with_delimiter(simulation.configured_at)} から今の設定で計算中（最初に戻すと 0 から）"
  end

  def roads(graph)
    graph.links.values.map { |link| [ link.from, link.to ].sort }.uniq.map { |ids| graph.nodes.values_at(*ids) }
  end

  private
    def junction_letter(index)
      letters = ("A".."Z").to_a
      index < letters.size ? letters[index] : "#{letters[index % letters.size]}#{index / letters.size}"
    end

    def edge_of(node)
      if node.x.zero? then :west
      elsif node.x == Network::SIZE then :east
      elsif node.y.zero? then :north
      elsif node.y == Network::SIZE then :south
      end
    end

    def link_geometry(graph, link)
      from, to = graph.nodes.values_at(link.from, link.to)
      length = Math.hypot(to.x - from.x, to.y - from.y)
      [ from, to, (to.x - from.x) / length, (to.y - from.y) / length ]
    end
end
