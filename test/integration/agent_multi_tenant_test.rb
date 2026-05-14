require "test_helper"

class AgentMultiTenantTest < ActionDispatch::IntegrationTest
  setup do
    @account_x = accounts(:"37s")
    @account_y = accounts(:initech)
    @agent_x   = users(:review_bot)             # belongs to 37s
    @token_x   = @agent_x.identity.access_tokens.create!(description: "x", permission: :write).token
  end

  test "agent token from account X cannot list cards in account Y" do
    get "#{@account_y.slug}/cards", headers: bearer(@token_x)
    refute_equal 200, response.status, "Must not return success cross-account"
  end

  test "agent_completion on a card belonging to another account returns 404 or 403" do
    # Find a card on Initech if any; otherwise we still test the 37s agent against
    # an Initech URL even if no Initech cards exist (the URL itself should be invalid for this agent).
    initech_card_number = accounts(:initech).cards.first&.number || 1

    post "#{@account_y.slug}/cards/#{initech_card_number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "none" } }.to_json,
      headers: bearer(@token_x).merge("Content-Type" => "application/json", "Idempotency-Key" => SecureRandom.uuid)
    refute_equal 201, response.status
    refute_equal 200, response.status
  end

  test "admin from account X cannot list agents in account Y" do
    admin_x = users(:kevin)
    admin_x_token = admin_x.identity.access_tokens.create!(description: "x", permission: :write).token
    get "#{@account_y.slug}/agents", headers: bearer(admin_x_token)
    refute_equal 200, response.status
  end

  test "deleting account X cascades the agent's data" do
    skip "Account deletion is a heavy operation tested separately upstream"
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
