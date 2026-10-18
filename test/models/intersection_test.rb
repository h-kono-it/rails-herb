require "test_helper"

class IntersectionTest < ActiveSupport::TestCase
  def build(**options)
    Intersection.new(size: 60, horizontal_density: 0.2, vertical_density: 0.2, cycle: 40, split: 0.5, slowdown: 0.2, **options)
  end

  test "no two cars ever share a cell" do
    [ [ 0.1, 0.1 ], [ 0.3, 0.2 ], [ 0.5, 0.5 ] ].product([ 1, 2, 3 ]).each do |(horizontal, vertical), seed|
      intersection = build(horizontal_density: horizontal, vertical_density: vertical, seed:)

      1_000.times do
        intersection.step
        cells = intersection.cars.map { |car| intersection.cell(car.lane, car.position) }
        assert_equal cells.size, cells.uniq.size, "collision at t=#{intersection.time} (h=#{horizontal}, v=#{vertical}, seed=#{seed})"
      end
    end
  end

  test "cars only enter the box on green" do
    intersection = build(horizontal_density: 0.3, vertical_density: 0.3)

    1_000.times do
      before = intersection.cars.to_h { |car| [ car.id, car ] }
      lights = Intersection::LANES.to_h { |lane| [ lane, intersection.light(lane) ] }
      intersection.step

      intersection.cars.each do |car|
        entered = before[car.id].position < intersection.box_entry && car.position >= intersection.box_entry && car.position <= intersection.box_exit
        assert_equal :green, lights[car.lane], "#{car.lane} car #{car.id} entered on #{lights[car.lane]} at t=#{intersection.time}" if entered
      end
    end
  end

  test "traffic keeps moving through the intersection" do
    intersection = build(horizontal_density: 0.3, vertical_density: 0.3).run(2_000)

    assert_operator intersection.recent_throughput, :>, 0
  end

  test "is deterministic for a seed" do
    assert_equal build(seed: 7).run(300).cars, build(seed: 7).run(300).cars
  end

  test "splits the green time by the given share" do
    intersection = build(cycle: 40, split: 0.75)

    assert_equal 24, intersection.green_horizontal
    assert_equal 8, intersection.green_vertical
    assert_equal 40, intersection.cycle
  end
end
