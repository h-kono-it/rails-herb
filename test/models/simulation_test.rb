require "test_helper"

class SimulationTest < ActiveSupport::TestCase
  # A crossroads at (30, 30) with dead ends on all four sides, plus a short
  # side street so some links are only a few cells long.
  def graph(signalized: true)
    nodes = [
      Simulation::Node.new(id: 1, x: 30, y: 30, signalized:),
      Simulation::Node.new(id: 2, x: 0, y: 30, signalized: false),
      Simulation::Node.new(id: 3, x: 60, y: 30, signalized: false),
      Simulation::Node.new(id: 4, x: 30, y: 0, signalized: false),
      Simulation::Node.new(id: 5, x: 30, y: 33, signalized: false),
      Simulation::Node.new(id: 6, x: 33, y: 33, signalized: false)
    ]
    pairs = [ [ 1, 2 ], [ 1, 3 ], [ 1, 4 ], [ 1, 5 ], [ 5, 6 ] ]
    links = pairs.flat_map { |a, b| [ [ a, b ], [ b, a ] ] }.each_with_index.map do |(from, to), id|
      Simulation::Link.new(id:, from:, to:, speed_limit: 5)
    end
    Simulation::Graph.new(nodes:, links:)
  end

  def link_between(graph, from, to)
    graph.links.values.find { |link| link.from == from && link.to == to }.id
  end

  def build(**options)
    Simulation.new(graph: graph, inflow: 0.3, cycle: 30, split: 0.5, slowdown: 0.2, **options)
  end

  test "no two cars ever share a cell" do
    [ 0.1, 0.3, 0.8 ].product([ 1, 2, 3 ]).each do |inflow, seed|
      simulation = build(inflow:, seed:)

      800.times do
        simulation.step
        cells = simulation.cars.map { |car| [ car.link, car.position ] }
        assert_equal cells.size, cells.uniq.size, "collision at t=#{simulation.time} (inflow=#{inflow}, seed=#{seed})"
        simulation.cars.each { |car| assert car.position.between?(0, simulation.graph.length(car.link) - 1) }
      end
    end
  end

  test "every car that entered is either still on the road or has left" do
    simulation = build(inflow: 0.5).run(1_000)

    assert_operator simulation.total_exits, :>, 0
    assert_equal simulation.total_spawned, simulation.total_exits + simulation.cars.size
  end

  test "cars cross a signalized junction on green, or on yellow to turn right" do
    simulation = build(inflow: 0.5)

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
    [ true, false ].each do |signalized|
      simulation = Simulation.new(graph: graph(signalized:), inflow: 0.4, cycle: 30, split: 0.5, slowdown: 0.2)
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
    b = network.nodes.create!(x: 10, y: 0, signalized: true)
    network.connect(a, b)

    graph = network.graph

    assert_equal 2, graph.links.size
    assert_equal [ 10, 10 ], graph.links.keys.map { |id| graph.length(id) }
    assert graph.nodes[b.id].signalized
  end
end
