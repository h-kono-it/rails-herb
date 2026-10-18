# Fixed-time two-phase signal: horizontal green, yellow, all red, then
# vertical green, yellow, all red. `split` is the horizontal share of the
# green time.
class SignalPlan
  Phase = Data.define(:horizontal, :vertical)

  YELLOW = 2
  ALL_RED = 2

  attr_reader :cycle, :green_horizontal, :green_vertical

  def initialize(cycle:, split:)
    green = [ cycle - 2 * (YELLOW + ALL_RED), 2 ].max
    @green_horizontal = (green * split).round.clamp(1, green - 1)
    @green_vertical = green - @green_horizontal
    @cycle = green + 2 * (YELLOW + ALL_RED)
  end

  def phase(time)
    t = time % @cycle
    vertical_start = @green_horizontal + YELLOW + ALL_RED

    if t < @green_horizontal then Phase.new(horizontal: :green, vertical: :red)
    elsif t < @green_horizontal + YELLOW then Phase.new(horizontal: :yellow, vertical: :red)
    elsif t < vertical_start then Phase.new(horizontal: :red, vertical: :red)
    elsif t < vertical_start + @green_vertical then Phase.new(horizontal: :red, vertical: :green)
    elsif t < vertical_start + @green_vertical + YELLOW then Phase.new(horizontal: :red, vertical: :yellow)
    else Phase.new(horizontal: :red, vertical: :red)
    end
  end

  def light(axis, time)
    phase(time).public_send(axis)
  end
end
