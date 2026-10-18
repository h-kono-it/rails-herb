require "test_helper"

class NodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @network = Network.create!(name: "test")
    @node = @network.nodes.create!(x: 0, y: 30)
  end

  test "updates the inflow" do
    patch node_path(@node), params: { node: { inflow: 40 } }, as: :json

    assert_response :no_content
    assert_equal 40, @node.reload.inflow
  end

  test "updates the signal plan" do
    patch node_path(@node), params: { node: { signalized: "1", cycle: 60, split: 70, offset: 12 } }, as: :json

    assert_response :no_content
    @node.reload
    assert @node.signalized
    assert_equal [ 60, 70, 12 ], [ @node.cycle, @node.split, @node.offset ]
  end

  test "rejects a cycle out of range" do
    patch node_path(@node), params: { node: { cycle: 5 } }, as: :json

    assert_response :unprocessable_content
    assert_equal 40, @node.reload.cycle
  end

  test "rejects an inflow out of range" do
    patch node_path(@node), params: { node: { inflow: 150 } }, as: :json

    assert_response :unprocessable_content
    assert_equal 15, @node.reload.inflow
  end
end
