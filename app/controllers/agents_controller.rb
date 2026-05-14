class AgentsController < ApplicationController
  SLUG_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/

  wrap_parameters :agent, include: %i[ name slug webhook_url all_access_boards permission ]

  before_action :ensure_admin
  before_action :set_agent, only: %i[ show update destroy ]

  def index
    @agents = Current.account.users.where(role: :agent).order(:name)
  end

  def show
  end

  def create
    params_hash = agent_params
    slug = params_hash[:slug].to_s

    unless slug.match?(SLUG_FORMAT) && slug.length.between?(2, 50)
      return render json: { errors: { slug: [ "must be 2-50 chars, lowercase letters/numbers/hyphens" ] } }, status: :unprocessable_entity
    end

    email = "#{slug}@agent.local"
    if Identity.exists?(email_address: email)
      return render json: { errors: { slug: [ "already taken" ] } }, status: :unprocessable_entity
    end

    ApplicationRecord.transaction do
      identity = Identity.create!(email_address: email)
      @agent = Current.account.users.create!(role: :agent, name: params_hash[:name], active: true, identity: identity)
      AgentSetting.create!(
        user: @agent,
        webhook_url: params_hash[:webhook_url],
        all_access_boards: params_hash.fetch(:all_access_boards, true)
      )
      @initial_token = identity.access_tokens.create!(
        description: "Initial token",
        permission: params_hash[:permission].presence || "write"
      )
    end

    render :create, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  end

  def update
    permitted = agent_params.slice(:name, :webhook_url, :all_access_boards)
    ApplicationRecord.transaction do
      @agent.update!(name: permitted[:name]) if permitted[:name].present?
      if permitted.key?(:webhook_url) || permitted.key?(:all_access_boards)
        setting = AgentSetting.find_or_initialize_by(user: @agent)
        setting.webhook_url = permitted[:webhook_url] if permitted.key?(:webhook_url)
        setting.all_access_boards = permitted[:all_access_boards] if permitted.key?(:all_access_boards)
        setting.save!
      end
    end
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  end

  def destroy
    ApplicationRecord.transaction do
      identity = @agent.identity
      @agent.assignments.destroy_all
      identity&.destroy!
      @agent.destroy!
    end
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def agent_params
      params.expect(agent: [ :name, :slug, :webhook_url, :all_access_boards, :permission ])
    end
end
