class NodesController < ApplicationController
  def update
    node = Node.find(params[:id])

    if node.update(params.expect(node: [ :inflow ]))
      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to node.network }
      end
    else
      respond_to do |format|
        format.json { render json: node.errors, status: :unprocessable_content }
        format.html { redirect_to node.network, alert: node.errors.full_messages.to_sentence }
      end
    end
  end
end
