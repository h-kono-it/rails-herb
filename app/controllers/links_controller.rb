class LinksController < ApplicationController
  def update
    link = Link.find(params[:id])

    if link.update(params.expect(link: %i[left_weight straight_weight right_weight right_turn_lane]))
      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to link.network }
      end
    else
      respond_to do |format|
        format.json { render json: link.errors, status: :unprocessable_content }
        format.html { redirect_to link.network, alert: link.errors.full_messages.to_sentence }
      end
    end
  end
end
