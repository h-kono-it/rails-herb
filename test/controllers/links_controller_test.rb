require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    network = Network.create!(name: "test")
    network.connect(network.nodes.create!(x: 0, y: 30), network.nodes.create!(x: 30, y: 30))
    @link = network.links.first
  end

  test "updates a turn weight" do
    patch link_path(@link), params: { link: { right_weight: 70 } }, as: :json

    assert_response :no_content
    assert_equal({ left: 20, straight: 60, right: 70 }, @link.reload.turn_weights)
  end

  test "sets the length of a right-turn lane" do
    patch link_path(@link), params: { link: { right_turn_lane: 8 } }, as: :json

    assert_response :no_content
    assert_equal 8, @link.reload.right_turn_lane
  end

  test "rejects a right-turn lane longer than 15 cells" do
    patch link_path(@link), params: { link: { right_turn_lane: 16 } }, as: :json

    assert_response :unprocessable_content
    assert_equal 0, @link.reload.right_turn_lane
  end

  test "rejects a weight out of range" do
    patch link_path(@link), params: { link: { left_weight: -1 } }, as: :json

    assert_response :unprocessable_content
    assert_equal 20, @link.reload.left_weight
  end
end
