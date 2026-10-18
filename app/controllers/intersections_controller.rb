class IntersectionsController < ApplicationController
  GRID_SIZE = 60
  # Every request replays from step 0, which costs about 80ms per 1,000 steps
  MAX_STEPS = 2_000

  def show
    @step = herb_state("step", 0).to_i.clamp(0, MAX_STEPS)
    @intersection = Intersection.new(
      size: GRID_SIZE,
      horizontal_density: herb_state("ew_density", 15).to_i / 100.0,
      vertical_density: herb_state("ns_density", 15).to_i / 100.0,
      cycle: herb_state("cycle", 40).to_i,
      split: herb_state("split", 50).to_i / 100.0,
      slowdown: herb_state("slowdown", 15).to_i / 100.0,
      seed: herb_state("seed", 1).to_i
    ).run(@step)
  end
end
