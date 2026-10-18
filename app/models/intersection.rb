# Two crossing roads, one lane each way, meeting at a signalized intersection.
# Traffic keeps left. Every lane wraps around, so a car leaving one edge comes
# back at the opposite one.
#
# Each lane runs the Nagel–Schreckenberg rules, with two extra obstacles in
# front of the intersection box (the 2x2 cells where the roads cross):
#
# - a car stops at the stop line unless its light is green
# - a car does not enter the box unless the cell after the box is free, so a
#   jam on the far side never leaves a car stuck inside
#
# Like RingRoad it is deterministic for a given seed.
class Intersection
  Car = Data.define(:id, :lane, :position, :velocity)

  LANES = %i[east west south north].freeze
  HORIZONTAL = %i[east west].freeze
  THROUGHPUT_WINDOW = 100

  attr_reader :size, :vmax, :cars, :time

  delegate :cycle, :green_horizontal, :green_vertical, to: :@signal

  def initialize(size:, horizontal_density:, vertical_density:, cycle:, split:, slowdown:, vmax: 5, seed: 1)
    raise ArgumentError, "size must be even" if size.odd?

    @size = size
    @center = size / 2
    @vmax = vmax
    @slowdown = slowdown
    @random = Random.new(seed)
    @time = 0
    @passes = []

    @signal = SignalPlan.new(cycle:, split:)

    @cars = LANES.flat_map do |lane|
      density = HORIZONTAL.include?(lane) ? horizontal_density : vertical_density
      place(lane, density)
    end
    @cars = @cars.each_with_index.map { |car, id| car.with(id:) }
  end

  def step
    occupied = @cars.to_h { |car| [ cell(car.lane, car.position), car ] }
    passed = 0

    @cars = @cars.group_by(&:lane).flat_map do |_lane, lane_cars|
      lane_cars = lane_cars.sort_by(&:position)
      lane_cars.each_with_index.map do |car, index|
        ahead = lane_cars[(index + 1) % lane_cars.size]
        gap = (ahead.position - car.position - 1) % @size

        velocity = [ car.velocity + 1, @vmax, gap, allowed_advance(car, gap, ahead.velocity, occupied) ].min
        velocity = [ velocity - 1, 0 ].max if @random.rand < @slowdown

        passed += 1 if car.position <= box_exit && car.position + velocity > box_exit
        car.with(position: (car.position + velocity) % @size, velocity:)
      end
    end

    @passes << passed
    @passes.shift if @passes.size > THROUGHPUT_WINDOW
    @time += 1
    self
  end

  def run(steps)
    steps.times { step }
    self
  end

  def phase(time = @time)
    @signal.phase(time)
  end

  def light(lane)
    HORIZONTAL.include?(lane) ? phase.horizontal : phase.vertical
  end

  # Grid cell [x, y] of a lane position. y grows downwards.
  def cell(lane, position)
    case lane
    when :east then [ position, @center - 1 ]
    when :west then [ @size - 1 - position, @center ]
    when :south then [ @center, position ]
    when :north then [ @center - 1, @size - 1 - position ]
    end
  end

  def box_entry = @center - 1
  def box_exit = @center

  def cars_in(lane)
    @cars.select { |car| car.lane == lane }
  end

  # Cars standing still within `reach` cells before the stop line.
  def queue_length(lane, reach: 20)
    cars_in(lane).count { |car| car.velocity.zero? && (box_entry - car.position).between?(1, reach) }
  end

  def average_velocity(cars = @cars)
    return 0.0 if cars.empty?

    cars.sum(&:velocity).fdiv(cars.size)
  end

  # Cars that crossed the box in the last THROUGHPUT_WINDOW steps.
  def recent_throughput
    @passes.sum
  end

  private
    def place(lane, density)
      free = (0...@size).reject { |position| in_box?(position) }
      count = (free.size * density).round.clamp(0, free.size)
      free.sample(count, random: @random).sort.map { |position| Car.new(id: nil, lane:, position:, velocity: 0) }
    end

    def in_box?(position)
      position == box_entry || position == box_exit
    end

    # How far a car may move given the signal and the intersection box.
    def allowed_advance(car, gap, ahead_velocity, occupied)
      return @vmax if in_box?(car.position)

      to_stop_line = (box_entry - car.position - 1) % @size
      return to_stop_line unless light(car.lane) == :green
      # Don't block the box: the cell right after it must be free, counting
      # on the car ahead to keep its speed (if it doesn't, the check below
      # still keeps crossing traffic out)
      return to_stop_line if gap + ahead_velocity < to_stop_line + 3

      # Never drive into a box cell a crossing car is still in
      [ box_entry, box_exit ].each_with_index do |position, offset|
        other = occupied[cell(car.lane, position)]
        return to_stop_line + offset if other && other.lane != car.lane
      end

      @vmax
    end
end
