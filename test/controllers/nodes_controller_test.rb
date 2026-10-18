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

  test "rejects an inflow out of range" do
    patch node_path(@node), params: { node: { inflow: 150 } }, as: :json

    assert_response :unprocessable_content
    assert_equal 15, @node.reload.inflow
  end
end
