class TrafficController < ApplicationController
  ROAD_LENGTH = 120
  HISTORY_ROWS = 80
  MAX_STEPS = 5_000

  def show
    @step = herb_state("step", 0).to_i.clamp(0, MAX_STEPS)
    @road = RingRoad.new(
      length: ROAD_LENGTH,
      density: herb_state("density", 25).to_i / 100.0,
      slowdown: herb_state("slowdown", 20).to_i / 100.0,
      seed: herb_state("seed", 1).to_i
    )
    @history = @road.run(@step, keep: HISTORY_ROWS)
  end
end
