require "application_system_test_case"

class NetworksTest < ApplicationSystemTestCase
  setup do
    @network = Network.create!(name: "十字路")
    center = @network.nodes.create!(x: 30, y: 30, signalized: true)
    @west = @network.nodes.create!(x: 0, y: 30, inflow: 100)
    @network.connect(@west, center)
    @network.connect(@network.nodes.create!(x: 60, y: 30), center)
  end

  test "steps the simulation without reloading the page" do
    visit network_path(@network)
    assert_selector "h1", text: "十字路"

    3.times { click_on "1ステップ" }

    within(".traffic__stats") { assert_text "ステップ\n3" }
    assert_selector ".network__car", minimum: 1
  end

  test "saves a dead end's inflow from its slider" do
    visit network_path(@network)

    slider = find("input[aria-label='西端 (0, 30)の流入']")
    slider.set(40)

    assert_selector "output", text: "40"
    assert_equal 40, wait_for { @west.reload.inflow == 40 && @west.inflow }
  end

  test "picks a junction and saves a turn weight" do
    north = @network.nodes.create!(x: 30, y: 0)
    @network.connect(north, @network.nodes.find_by!(x: 30, y: 30))
    from_west = @network.links.find_by!(from_node: @west)

    visit network_path(@network)
    assert_selector "caption", text: "交差点 (30, 30) の進行方向"

    # From the west the junction offers left (north) and straight on (east), but no right turn
    assert_no_selector "input[aria-label='西からの右折の重み']"
    find("input[aria-label='西からの左折の重み']").set(80)

    assert_equal 80, wait_for { from_west.reload.left_weight == 80 && from_west.left_weight }
    assert_text "設定 57%" # 80 / (80 + 60)
  end

  test "adds a right-turn lane and draws it" do
    from_west = @network.links.find_by!(from_node: @west)

    visit network_path(@network)
    assert_no_selector ".network__pocket"

    find("input[aria-label='西からの右折レーンの長さ']").set(10)

    assert_equal 10, wait_for { from_west.reload.right_turn_lane == 10 && from_west.right_turn_lane }
    assert_selector ".network__pocket", count: 1
  end

  private
    def wait_for(timeout: Capybara.default_max_wait_time)
      deadline = Time.current + timeout
      loop do
        result = yield
        return result if result || Time.current > deadline

        sleep 0.1
      end
    end
end
