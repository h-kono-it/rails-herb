# Nagel–Schreckenberg traffic on an arbitrary road network.
#
# Each link is a one-way lane of cells. Nodes have no length: a car that runs
# past the end of its link continues on the next one in the same step.
#
# - Dead ends (nodes with a single neighbour) are where cars enter and leave.
#   Each dead end sends in `inflow` cars per 100 steps on average. Cars that
#   arrive while the entry cell is taken wait outside the network, in order.
# - At a junction a car picks its next road by the turn weights of the link
#   it arrives on (left, straight, right), spread over the roads the junction
#   offers. It never goes back the way it came unless there is no other road.
# - At a signalized junction a car may only cross on green. Each junction
#   runs its own fixed-time plan (cycle, split, offset). Links running
#   left-right follow the horizontal phase, the others the vertical one.
# - Turning right crosses the oncoming lane (traffic keeps left), so a right
#   turner waits at the stop line while an oncoming car going straight or left
#   is about to enter the junction, holding up everyone behind it. On yellow
#   the oncoming cars have stopped, and a right turner waiting at the line
#   goes.
# - When several cars want the same lane in one step, left turns go first,
#   then straight on, then right turns, in random order within each. A car
#   that does not fit waits at the end of its own link.
#
# Like the other models it is deterministic for a given seed.
class Simulation
  # inflow: cars per 100 steps entering at this node, if it is a dead end
  # cycle, split, offset: the signal plan, if signalized (split in percent
  # of the green time for the horizontal phase, offset in steps)
  Node = Data.define(:id, :x, :y, :signalized, :inflow, :cycle, :split, :offset) do
    def initialize(cycle: 40, split: 50, offset: 0, **) = super
  end
  # turn_weights: { left:, straight:, right: } relative weights at the junction this link leads into
  Link = Data.define(:id, :from, :to, :speed_limit, :turn_weights)
  Car = Data.define(:id, :link, :position, :velocity, :next_link)

  class Graph
    attr_reader :nodes, :links

    def initialize(nodes:, links:)
      @nodes = nodes.index_by(&:id)
      @links = links.index_by(&:id)
      @outgoing = links.group_by(&:from)
      @incoming = links.group_by(&:to)
      @lengths = @links.transform_values { |link| [ distance(link).round, 1 ].max }
    end

    def outgoing(node_id) = @outgoing.fetch(node_id, [])
    def incoming(node_id) = @incoming.fetch(node_id, [])
    def length(link_id) = @lengths.fetch(link_id)

    def dead_end?(node_id)
      (outgoing(node_id).map(&:to) + incoming(node_id).map(&:from)).uniq.size == 1
    end

    def entries
      @links.values.select { |link| dead_end?(link.from) }
    end

    def axis(link)
      dx, dy = direction(link)
      dx.abs >= dy.abs ? :horizontal : :vertical
    end

    # :left, :straight or :right, going from one link onto the next. Turning
    # back counts as :right, since it crosses the oncoming lane too.
    def turn(from_link_id, to_link_id)
      ix, iy = direction(@links.fetch(from_link_id))
      ox, oy = direction(@links.fetch(to_link_id))
      sine = ix * oy - iy * ox # y grows downwards, so positive is clockwise
      cosine = ix * ox + iy * oy

      if sine > 0.5 || (sine.abs <= 0.5 && cosine < 0) then :right
      elsif sine < -0.5 then :left
      else :straight
      end
    end

    # The link coming into the same junction from the other side, if any.
    def opposing(link_id)
      link = @links.fetch(link_id)
      ix, iy = direction(link)
      incoming(link.to).find do |other|
        ox, oy = direction(other)
        other.from != link.from && ix * ox + iy * oy < -0.9
      end
    end

    private
      def distance(link)
        from, to = @nodes.values_at(link.from, link.to)
        Math.hypot(to.x - from.x, to.y - from.y)
      end

      # Unit vector along a link
      def direction(link)
        from, to = @nodes.values_at(link.from, link.to)
        length = distance(link)
        [ (to.x - from.x) / length, (to.y - from.y) / length ]
      end
  end

  THROUGHPUT_WINDOW = 100
  TURN_PRIORITY = { left: 0, straight: 1, right: 2 }.freeze

  attr_reader :graph, :cars, :time, :total_exits

  def initialize(graph:, slowdown:, seed: 1)
    @graph = graph
    @slowdown = slowdown
    @plans = graph.nodes.values.select(&:signalized).to_h do |node|
      [ node.id, SignalPlan.new(cycle: node.cycle, split: node.split / 100.0) ]
    end
    @random = Random.new(seed)
    @cars = []
    @next_id = 0
    @time = 0
    @exits = []
    @total_exits = 0
    @waiting = Hash.new(0)
    @entered = Hash.new(0)
    @left = Hash.new(0)
    @turns = Hash.new(0)
  end

  def step
    lanes = @cars.group_by(&:link).transform_values { |cars| cars.sort_by(&:position) }
    staying = []
    crossing = []
    exited = 0

    lanes.each do |link_id, cars|
      link = @graph.links.fetch(link_id)
      length = @graph.length(link_id)

      cars.each_with_index do |car, index|
        leader = cars[index + 1]
        gap = leader ? leader.position - car.position - 1 : length - 1 - car.position + room_after(car, link, lanes)

        velocity = [ car.velocity + 1, link.speed_limit, gap ].min
        velocity = [ velocity - 1, 0 ].max if @random.rand < @slowdown
        position = car.position + velocity

        if position < length
          staying << car.with(position:, velocity:)
        elsif car.next_link.nil?
          exited += 1
          @left[link.to] += 1
        else
          crossing << [ car, position - length, velocity ]
        end
      end
    end

    @cars = staying + merge(crossing, staying)
    spawn
    @exits << exited
    @total_exits += exited
    @exits.shift if @exits.size > THROUGHPUT_WINDOW
    @time += 1
    self
  end

  def run(steps)
    steps.times { step }
    self
  end

  def light(link)
    current = phase(link.to)
    current ? current.public_send(@graph.axis(link)) : :green
  end

  # The signal plan of a junction, or nil if it has no signal.
  def plan(node_id) = @plans[node_id]

  # A signalized junction's current phase, or nil if it has no signal.
  def phase(node_id)
    plan = @plans[node_id] or return
    plan.phase(@time + @graph.nodes.fetch(node_id).offset)
  end

  def average_velocity(cars = @cars)
    return 0.0 if cars.empty?

    cars.sum(&:velocity).fdiv(cars.size)
  end

  def total_spawned = @next_id

  # Per dead end: cars waiting outside to get in, cars that got in, cars that left
  def waiting_at(node_id) = @waiting[node_id]
  def entered_at(node_id) = @entered[node_id]
  def left_at(node_id) = @left[node_id]
  def total_waiting = @waiting.values.sum

  # How many cars arriving on a link have gone each way at its junction.
  def turn_count(link_id, turn) = @turns[[ link_id, turn ]]

  # Cars that left the network in the last THROUGHPUT_WINDOW steps.
  def recent_exits
    @exits.sum
  end

  # Cars standing still on a link.
  def queue_length(link_id)
    @cars.count { |car| car.link == link_id && car.velocity.zero? }
  end

  # Whether a car is stopped at the stop line, waiting to turn right.
  def waiting_to_turn_right?(car)
    car.velocity.zero? && car.next_link.present? &&
      car.position == @graph.length(car.link) - 1 && @graph.turn(car.link, car.next_link) == :right
  end

  def waiting_to_turn_right(link_id)
    @cars.count { |car| car.link == link_id && waiting_to_turn_right?(car) }
  end

  private
    # Free cells a lane leader may use past the end of its link.
    def room_after(car, link, lanes)
      return link.speed_limit if car.next_link.nil?
      return 0 unless may_cross?(car, link, lanes)

      first = lanes[car.next_link]&.first
      first ? first.position : @graph.length(car.next_link)
    end

    # Lets crossing cars onto their next link one at a time, so two cars
    # turning into the same lane never land on the same cell.
    def merge(crossing, staying)
      tails = staying.group_by(&:link).transform_values { |cars| cars.map(&:position).min }
      # Keep the end of each crossing car's own link free, in case it has to wait there
      crossing.each do |car, _, _|
        tails[car.link] = [ tails[car.link], @graph.length(car.link) - 1 ].compact.min
      end

      ordered = crossing.shuffle(random: @random).each_with_index.sort_by do |(car, _, _), index|
        [ TURN_PRIORITY.fetch(@graph.turn(car.link, car.next_link)), index ]
      end

      ordered.map do |(car, position, velocity), _|
        limit = [ (tails[car.next_link] || @graph.length(car.next_link)) - 1, position ].min

        if limit.negative?
          car.with(position: @graph.length(car.link) - 1, velocity: 0)
        else
          tails[car.next_link] = limit
          @turns[[ car.link, @graph.turn(car.link, car.next_link) ]] += 1
          link = @graph.links.fetch(car.next_link)
          car.with(link: link.id, position: limit, velocity: [ velocity, limit + 1 ].min, next_link: choose_next(link))
        end
      end
    end

    def may_cross?(car, link, lanes)
      right = @graph.turn(link.id, car.next_link) == :right

      case light(link)
      when :green then !right || !oncoming?(link, lanes)
      when :yellow then right && car.position == @graph.length(link.id) - 1
      else false
      end
    end

    # Whether the front car on the opposing link is about to enter the
    # junction this step, going straight or turning left.
    def oncoming?(link, lanes)
      opposing = @graph.opposing(link.id)
      return false unless opposing && light(opposing) == :green

      leader = lanes[opposing.id]&.last
      return false unless leader&.next_link
      return false if @graph.turn(opposing.id, leader.next_link) == :right

      reach = [ leader.velocity + 1, opposing.speed_limit ].min
      reach > @graph.length(opposing.id) - 1 - leader.position
    end

    def spawn
      taken = @cars.select { |car| car.position.zero? }.map(&:link).to_set

      @graph.entries.each do |link|
        @waiting[link.from] += 1 if @random.rand < @graph.nodes.fetch(link.from).inflow / 100.0
        next if @waiting[link.from].zero? || taken.include?(link.id)

        @waiting[link.from] -= 1
        @entered[link.from] += 1
        @cars << Car.new(id: @next_id, link: link.id, position: 0, velocity: 0, next_link: choose_next(link))
        @next_id += 1
      end
    end

    def choose_next(link)
      return nil if @graph.dead_end?(link.to)

      options = @graph.outgoing(link.to).reject { |other| other.to == link.from }
      return @graph.outgoing(link.to).sample(random: @random).id if options.empty?

      # Each turn's weight is shared by the roads that make that turn
      by_turn = options.group_by { |other| @graph.turn(link.id, other.id) }
      weighted = by_turn.flat_map do |turn, roads|
        roads.map { |road| [ road, link.turn_weights.fetch(turn, 0).fdiv(roads.size) ] }
      end
      total = weighted.sum { |_, weight| weight }
      return options.sample(random: @random).id if total.zero?

      pick = @random.rand * total
      weighted.each do |road, weight|
        return road.id if pick < weight

        pick -= weight
      end
      weighted.last.first.id
    end
end
