class Cards::AgentCompletionsController < ApplicationController
  include CardScoped

  before_action :ensure_agent

  def create
    # Idempotency short-circuit: return the first completion record for this key
    # without re-checking assignment (agent may have been unassigned after first run).
    if (key = request.headers["Idempotency-Key"]).present?
      if (@completion = Card::AgentCompletion.find_by(card: @card, user: Current.user, idempotency_key: key))
        return render :create, status: :created, location: card_url(@card)
      end
    end

    unless @card.assigned_to?(Current.user)
      return head :forbidden
    end

    raw = params.require(:agent_completion)
    unless raw[:result].present?
      return render json: { errors: { result: [ "is required" ] } }, status: :unprocessable_entity
    end

    @completion = Card::AgentCompletion.record!(
      card: @card,
      agent: Current.user,
      result: raw[:result],
      summary: raw[:summary].to_s,
      details_html: raw[:details_html],
      outcome: raw[:outcome],
      artifacts: (raw[:artifacts] || []).map { |a| a.is_a?(ActionController::Parameters) ? a.permit(:label, :url).to_h : a },
      metrics: raw[:metrics].respond_to?(:to_unsafe_h) ? raw[:metrics].to_unsafe_h : (raw[:metrics] || {}),
      idempotency_key: key
    )

    render :create, status: :created, location: card_url(@card)
  rescue Card::AgentCompletion::NotAssigned
    head :forbidden
  rescue ActionController::ParameterMissing
    render json: { errors: { agent_completion: [ "is required" ] } }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
  end

  private
    def ensure_agent
      head :forbidden unless Current.user&.agent?
    end
end
