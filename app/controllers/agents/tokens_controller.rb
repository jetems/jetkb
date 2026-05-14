class Agents::TokensController < ApplicationController
  before_action :ensure_admin
  before_action :set_agent

  def index
    @tokens = @agent.identity.access_tokens.order(created_at: :desc)
  end

  def create
    @token = @agent.identity.access_tokens.create!(
      description: params.dig(:token, :description) || "Rotated",
      permission: params.dig(:token, :permission) || "write"
    )
    render :create, status: :created
  end

  def destroy
    token = @agent.identity.access_tokens.find(params[:id])
    token.destroy!
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:agent_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
