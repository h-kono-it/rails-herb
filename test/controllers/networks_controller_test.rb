require "test_helper"

class NetworksControllerTest < ActionDispatch::IntegrationTest
  TEMPLATE = "app/views/networks/show.html.erb"

  setup do
    @network = Network.create!(name: "test")
    @west = @network.nodes.create!(x: 0, y: 30, inflow: 40)
    @east = @network.nodes.create!(x: 60, y: 30, inflow: 40)
    @centre = @network.nodes.create!(x: 30, y: 30, signalized: true)
    @network.connect(@west, @centre)
    @network.connect(@centre, @east)

    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @cache
  end

  def show(step, seed: 1)
    get network_path(@network, format: :slots), headers: { "Herb-State" => { TEMPLATE => { step:, seed:, slowdown: 15 } }.to_json }
    assert_response :success
    controller.instance_variable_get(:@simulation)
  end

  def replay(steps, seed: 1)
    Simulation.new(graph: @network.reload.graph, slowdown: 0.15, seed:).run(steps)
  end

  test "carries the run on from the cached step" do
    show(300)
    assert_equal replay(301).cars, show(301).cars

    # A run that replaying could not produce shows the next request carries it on
    Rails.cache.write([ "networks", @network.id, "run", 1 ], replay(300, seed: 99))
    assert_equal replay(302, seed: 99).cars, show(302).cars
  end

  test "has no step limit" do
    assert_equal 6_000, show(6_000).time
  end

  test "applies changed settings from the current step" do
    show(200)
    @west.update!(inflow: 0)
    @east.update!(inflow: 0)

    simulation = show(201)

    assert_equal 200, simulation.configured_at
    assert_response_body_includes "ステップ 200 から今の設定で計算中"
    assert_not_equal replay(201).cars, simulation.cars, "not replayed with the new settings"
  end

  test "going back starts over with the current settings" do
    show(200)
    @west.update!(inflow: 0)
    show(201)

    simulation = show(0)
    assert_nil simulation.configured_at
    assert_equal replay(50).cars, show(50).cars
  end

  test "keeps a run for each seed" do
    show(100, seed: 1)
    show(100, seed: 2)

    assert_equal replay(101, seed: 1).cars, show(101, seed: 1).cars
  end

  private
    def assert_response_body_includes(text)
      assert_includes response.body, text
    end
end
