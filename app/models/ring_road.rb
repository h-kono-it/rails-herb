# Nagel–Schreckenberg model on a single-lane ring road.
#
# Each step every car, in parallel:
#   1. accelerates by 1 up to vmax
#   2. slows down to the number of empty cells in front of it
#   3. randomly slows down by 1 with probability `slowdown`
#   4. moves forward by its velocity
#
# The simulation is deterministic for a given seed, so any step can be
# reproduced by replaying from the start.
class RingRoad
  Car = Data.define(:id, :position, :velocity)
  Snapshot = Data.define(:time, :cars)

  attr_reader :length, :vmax, :cars, :time

  def initialize(length:, density:, slowdown:, vmax: 5, seed: 1)
    @length = length
    @vmax = vmax
    @slowdown = slowdown
    @random = Random.new(seed)
    @time = 0

    count = (length * density).round.clamp(1, length)
    positions = (0...length).to_a.sample(count, random: @random).sort
    @cars = positions.each_with_index.map { |position, id| Car.new(id:, position:, velocity: 0) }
  end

  def step
    @cars = @cars.each_with_index.map do |car, index|
      ahead = @cars[(index + 1) % @cars.size]
      gap = (ahead.position - car.position - 1) % @length

      velocity = [ car.velocity + 1, @vmax, gap ].min
      velocity = [ velocity - 1, 0 ].max if @random.rand < @slowdown

      car.with(position: (car.position + velocity) % @length, velocity:)
    end
    @time += 1
    self
  end

  # Runs `steps` steps and returns the last `keep` snapshots, oldest first.
  def run(steps, keep:)
    history = [ snapshot ]
    steps.times do
      step
      history << snapshot
      history.shift if history.size > keep
    end
    history
  end

  def snapshot
    Snapshot.new(time: @time, cars: @cars)
  end

  def average_velocity
    @cars.sum(&:velocity).fdiv(@cars.size)
  end

  def stopped_count
    @cars.count { |car| car.velocity.zero? }
  end
end
