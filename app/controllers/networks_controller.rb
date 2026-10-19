class NetworksController < ApplicationController
  # How long an untouched run stays in the cache
  RUN_EXPIRY = 1.hour

  def index
    @networks = Network.order(:id).includes(:nodes, :links)
  end

  def show
    @network = Network.find(params[:id])
    @networks = Network.order(:id)
    @step = [ herb_state("step", 0).to_i, 0 ].max
    @simulation = advance(
      graph: @network.graph,
      slowdown: herb_state("slowdown", 15).to_i / 100.0,
      seed: herb_state("seed", 1).to_i
    )
  end

  private
    # Each network and seed has one run in the cache, carried on from the
    # step it reached instead of replayed from step 0. Settings changed on
    # the way take effect from the current step. Going back to an earlier
    # step, or a run that is not cached, starts over with the current
    # settings.
    def advance(graph:, slowdown:, seed:)
      key = [ "networks", @network.id, "run", seed ]
      run = Rails.cache.read(key)
      run = nil unless run && run.time <= @step && run.graph.same_roads?(graph)
      run = run&.reconfigure(graph:, slowdown:) || Simulation.new(graph:, slowdown:, seed:)

      run.run(@step - run.time)
      Rails.cache.write(key, run, expires_in: RUN_EXPIRY)
      run
    end
end
