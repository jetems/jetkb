class Agents::BoardAccessesController < ApplicationController
  before_action :ensure_admin
  before_action :set_agent

  def index
    @accesses = @agent.accesses.includes(:board)
  end

  def create
    board = Current.account.boards.find(params.dig(:board_access, :board_id))
    @access = Access.find_or_create_by!(user: @agent, board: board)
    render :show, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { errors: { board_id: [ "not found" ] } }, status: :unprocessable_entity
  end

  def destroy
    Access.where(user: @agent, board_id: params[:id]).destroy_all
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:agent_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
