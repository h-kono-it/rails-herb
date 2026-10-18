class NetworksController < ApplicationController
  # Every request replays from step 0, which costs about 180ms per 1,000 steps on the 2x2 grid
  MAX_STEPS = 2_000

  def index
    @networks = Network.order(:id).includes(:nodes, :links)
  end

  def show
    @network = Network.find(params[:id])
    @networks = Network.order(:id)
    @step = herb_state("step", 0).to_i.clamp(0, MAX_STEPS)
    @simulation = Simulation.new(
      graph: @network.graph,
      slowdown: herb_state("slowdown", 15).to_i / 100.0,
      seed: herb_state("seed", 1).to_i
    ).run(@step)
  end
end
