require "test_helper"

class SimulationTest < ActiveSupport::TestCase
  # A crossroads at (30, 30) with dead ends on all four sides, plus a short
  # side street so some links are only a few cells long.
  DEFAULT_WEIGHTS = { left: 20, straight: 60, right: 20 }.freeze

  # weights: { [from, to] => { left:, straight:, right: } } and
  # pockets: { [from, to] => cells } for individual links
  def graph(signalized: true, inflow: 30, weights: {}, pockets: {})
    nodes = [
      Simulation::Node.new(id: 1, x: 30, y: 30, signalized:, inflow: 0),
      Simulation::Node.new(id: 2, x: 0, y: 30, signalized: false, inflow:),
      Simulation::Node.new(id: 3, x: 60, y: 30, signalized: false, inflow:),
      Simulation::Node.new(id: 4, x: 30, y: 0, signalized: false, inflow:),
      Simulation::Node.new(id: 5, x: 30, y: 33, signalized: false, inflow: 0),
      Simulation::Node.new(id: 6, x: 33, y: 33, signalized: false, inflow:)
    ]
    pairs = [ [ 1, 2 ], [ 1, 3 ], [ 1, 4 ], [ 1, 5 ], [ 5, 6 ] ]
    links = pairs.flat_map { |a, b| [ [ a, b ], [ b, a ] ] }.each_with_index.map do |(from, to), id|
      Simulation::Link.new(id:, from:, to:, speed_limit: 5, turn_weights: weights.fetch([ from, to ], DEFAULT_WEIGHTS), right_turn_lane: pockets.fetch([ from, to ], 0))
    end
    Simulation::Graph.new(nodes:, links:)
  end

  def link_between(graph, from, to)
    graph.links.values.find { |link| link.from == from && link.to == to }.id
  end

  def build(inflow: 30, signalized: true, weights: {}, pockets: {}, **options)
    Simulation.new(graph: graph(inflow:, signalized:, weights:, pockets:), cycle: 30, split: 0.5, slowdown: 0.2, **options)
  end

  POCKETS_INTO_CROSSROADS = { [ 2, 1 ] => 10, [ 3, 1 ] => 15, [ 4, 1 ] => 5, [ 5, 1 ] => 15 }.freeze

  test "no two cars ever share a cell" do
    [ 10, 30, 80 ].product([ 1, 2, 3 ], [ {}, POCKETS_INTO_CROSSROADS ]).each do |inflow, seed, pockets|
      simulation = build(inflow:, seed:, pockets:)

      800.times do
        simulation.step
        cells = simulation.cars.map { |car| [ car.link, car.pocket, car.position ] }
        assert_equal cells.size, cells.uniq.size, "collision at t=#{simulation.time} (inflow=#{inflow}, seed=#{seed}, pockets=#{pockets.any?})"
        simulation.cars.each { |car| assert car.position.between?(0, simulation.graph.length(car.link) - 1) }
      end
    end
  end

  test "every car that entered is either still on the road or has left" do
    simulation = build(inflow: 50).run(1_000)

    assert_operator simulation.total_exits, :>, 0
    assert_equal simulation.total_spawned, simulation.total_exits + simulation.cars.size
    entries = simulation.graph.entries.map(&:from)
    assert_equal simulation.total_spawned, entries.sum { |id| simulation.entered_at(id) }
    assert_equal simulation.total_exits, entries.sum { |id| simulation.left_at(id) }
  end

  test "each dead end sends in about its inflow" do
    simulation = build(inflow: 20, slowdown: 0).run(2_000)

    simulation.graph.entries.each do |link|
      arrived = simulation.entered_at(link.from) + simulation.waiting_at(link.from)
      assert_in_delta 400, arrived, 80, "dead end #{link.from} saw #{arrived} cars in 2,000 steps"
    end
  end

  test "cars that cannot get in wait outside instead of disappearing" do
    simulation = build(inflow: 100).run(500)

    assert_operator simulation.total_waiting, :>, 0
  end

  test "a dead end with no inflow sends nobody" do
    simulation = build(inflow: 0).run(300)

    assert_equal 0, simulation.total_spawned
    assert_equal 0, simulation.total_waiting
  end

  test "cars cross a signalized junction on green, or on yellow to turn right" do
    simulation = build(inflow: 50)

    600.times do
      before = simulation.cars.to_h { |car| [ car.id, car ] }
      lights = simulation.graph.links.transform_values { |link| simulation.light(link) }
      simulation.step

      simulation.cars.each do |car|
        previous = before[car.id]
        next if previous.nil? || previous.link == car.link

        light = lights[previous.link]
        turn = simulation.graph.turn(previous.link, car.link)
        assert light == :green || (light == :yellow && turn == :right), "car #{car.id} turned #{turn} on #{light}"
      end
    end
  end

  test "classifies turns, keeping left" do
    g = graph
    east_in = link_between(g, 2, 1)

    assert_equal :straight, g.turn(east_in, link_between(g, 1, 3))
    assert_equal :left, g.turn(east_in, link_between(g, 1, 4))
    assert_equal :right, g.turn(east_in, link_between(g, 1, 5))
    assert_equal :right, g.turn(east_in, link_between(g, 1, 2))
    assert_equal link_between(g, 3, 1), g.opposing(east_in).id
  end

  test "right turners never cross while oncoming traffic goes through" do
    [ true, false ].product([ {}, POCKETS_INTO_CROSSROADS ]).each do |signalized, pockets|
      simulation = build(inflow: 40, signalized:, pockets:)
      rights = 0

      1_500.times do
        before = simulation.cars.to_h { |car| [ car.id, car ] }
        simulation.step
        moves = simulation.cars.filter_map do |car|
          previous = before[car.id]
          [ previous.link, car.link ] if previous && previous.link != car.link
        end

        moves.each do |from, to|
          next unless simulation.graph.turn(from, to) == :right

          rights += 1
          oncoming = simulation.graph.opposing(from)&.id
          clash = moves.find { |other_from, other_to| other_from == oncoming && simulation.graph.turn(other_from, other_to) != :right }
          assert_nil clash, "right turn from link #{from} crossed oncoming traffic (signalized: #{signalized})"
        end
      end

      assert_operator rights, :>, 0
    end
  end

  test "cars split at a junction by the turn weights of the link they arrive on" do
    from_west = [ 2, 1 ]
    simulation = build(inflow: 30, weights: { from_west => { left: 1, straight: 0, right: 3 } }).run(2_000)
    link = link_between(simulation.graph, *from_west)

    left, straight, right = %i[left straight right].map { |turn| simulation.turn_count(link, turn) }
    assert_equal 0, straight
    assert_in_delta 0.75, right.fdiv(left + right), 0.08
  end

  test "weights of turns a junction does not offer are ignored" do
    # Node 5 is a bend: coming down from the crossroads, the only way on is left
    into_bend = [ 1, 5 ]
    simulation = build(inflow: 30, weights: { into_bend => { left: 1, straight: 100, right: 100 } }).run(1_000)
    link = link_between(simulation.graph, *into_bend)

    assert_operator simulation.turn_count(link, :left), :>, 0
    assert_equal 0, simulation.turn_count(link, :straight) + simulation.turn_count(link, :right)
  end

  test "all-zero weights fall back to an even split" do
    from_west = [ 2, 1 ]
    simulation = build(inflow: 30, weights: { from_west => { left: 0, straight: 0, right: 0 } }).run(1_000)
    link = link_between(simulation.graph, *from_west)

    %i[left straight right].each { |turn| assert_operator simulation.turn_count(link, turn), :>, 0, turn }
  end

  test "a right-turn pocket keeps straight traffic moving past waiting right turners" do
    from_west = [ 2, 1 ]
    # Half the cars from the west turn right, across a steady stream going straight from the east
    weights = { from_west => { left: 0, straight: 1, right: 1 }, [ 3, 1 ] => { left: 0, straight: 1, right: 0 } }

    straight = [ 0, 10 ].to_h do |cells|
      simulation = build(inflow: 35, weights:, pockets: { from_west => cells }).run(3_000)
      [ cells, simulation.turn_count(link_between(simulation.graph, *from_west), :straight) ]
    end

    assert_operator straight[10], :>, straight[0] * 1.3, "straight on from the west: #{straight}"
  end

  test "only right turners use the pocket, and it holds no more cars than it has cells" do
    simulation = build(inflow: 60, pockets: POCKETS_INTO_CROSSROADS)
    graph = simulation.graph
    used = false

    1_000.times do
      simulation.step
      simulation.cars.each do |car|
        if car.pocket
          used = true
          assert_equal :right, graph.turn(car.link, car.next_link)
          assert_operator car.position, :>=, graph.pocket_start(car.link)
        elsif car.next_link && graph.turn(car.link, car.next_link) == :right && graph.pocket_length(car.link).positive?
          assert_operator car.position, :<, graph.pocket_start(car.link), "right turner #{car.id} drove past the pocket entrance"
        end
      end
      simulation.cars.select(&:pocket).group_by(&:link).each do |link, cars|
        assert_operator cars.size, :<=, graph.pocket_length(link)
      end
    end

    assert used, "no car ever entered a pocket"
  end

  test "a pocket is shortened to leave room at the start of its link" do
    g = graph(pockets: { [ 2, 1 ] => 15, [ 1, 5 ] => 15 })

    assert_equal 15, g.pocket_length(link_between(g, 2, 1))
    assert_equal 15, g.pocket_start(link_between(g, 2, 1))
    assert_equal 0, g.pocket_length(link_between(g, 1, 5)), "a 3-cell link has no room for a pocket"
    assert_equal 0, g.pocket_length(link_between(g, 1, 2))
  end

  test "dead ends are where cars enter and leave" do
    g = graph

    assert g.dead_end?(2)
    assert_not g.dead_end?(1)
    assert_not g.dead_end?(5)
    assert_equal [ 2, 3, 4, 6 ], g.entries.map(&:from).sort
  end

  test "is deterministic for a seed" do
    assert_equal build(seed: 4).run(300).cars, build(seed: 4).run(300).cars
  end

  test "a network turns into a simulation graph" do
    network = Network.create!(name: "test")
    a = network.nodes.create!(x: 0, y: 0)
    b = network.nodes.create!(x: 10, y: 0, signalized: true, inflow: 0)
    network.connect(a, b)

    graph = network.graph

    assert_equal 2, graph.links.size
    assert_equal [ 10, 10 ], graph.links.keys.map { |id| graph.length(id) }
    assert graph.nodes[b.id].signalized
    assert_equal [ 15, 0 ], graph.nodes.values_at(a.id, b.id).map(&:inflow)
    assert_equal({ left: 20, straight: 60, right: 20 }, graph.links.values.first.turn_weights)
    assert_equal 0, graph.links.values.first.right_turn_lane
  end
end
