require "test_helper"

class AgentApiAccessTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @agent_identity = Identity.create!(email_address: "api-test-bot-#{SecureRandom.hex(4)}@agent.local")
    @agent = @account.users.create!(role: :agent, name: "Test Bot", identity: @agent_identity, active: true)
    @token = @agent_identity.access_tokens.create!(description: "test", permission: :write).token
  end

  test "agent token can list cards via JSON" do
    get "#{@account.slug}/cards.json", headers: bearer(@token)
    assert_response :ok
  end

  test "agent token can fetch a card via JSON" do
    get "#{@account.slug}/cards/#{cards(:logo).number}.json", headers: bearer(@token)
    assert_response :ok
  end

  test "missing token is denied (redirect to login, not 200)" do
    get "#{@account.slug}/cards.json", headers: { "Accept" => "application/json" }
    # No Authorization header at all → request_authentication → 302 redirect to /session/new
    # (Bearer-specific 401 only fires when the header includes "Bearer" but the token is invalid)
    refute_equal 200, response.status
  end

  test "agent token from one account cannot access another account's resources" do
    other_account = accounts(:initech)
    get "#{other_account.slug}/cards.json", headers: bearer(@token)
    # Must not be 200; either 401/403/404 is acceptable (we don't want to leak existence)
    refute_equal 200, response.status
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
