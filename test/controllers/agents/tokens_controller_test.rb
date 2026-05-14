require "test_helper"

class Agents::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @admin = users(:kevin)
    @admin_token = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @agent = users(:review_bot)
  end

  test "admin can rotate a token and receive plaintext once" do
    assert_difference -> { @agent.identity.access_tokens.count } => 1 do
      post "#{@account.slug}/agents/#{@agent.id}/tokens",
        params: { token: { description: "rotation" } }.to_json,
        headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    end
    assert_response :created
    assert response.parsed_body["token"].present?
  end

  test "list omits plaintext token field" do
    @agent.identity.access_tokens.create!(description: "existing", permission: :read)
    get "#{@account.slug}/agents/#{@agent.id}/tokens", headers: bearer(@admin_token)
    assert_response :ok
    token_row = response.parsed_body.find { |t| t["description"] == "existing" }
    refute_nil token_row
    refute token_row.key?("token"), "plaintext token must not appear in list"
  end

  test "admin can revoke a token" do
    token = @agent.identity.access_tokens.create!(description: "to_delete", permission: :read)
    delete "#{@account.slug}/agents/#{@agent.id}/tokens/#{token.id}", headers: bearer(@admin_token)
    assert_response :no_content
    assert_nil Identity::AccessToken.find_by(id: token.id)
  end

  test "agent cannot rotate own token" do
    agent_token = @agent.identity.access_tokens.create!(description: "self", permission: :write).token
    post "#{@account.slug}/agents/#{@agent.id}/tokens",
      params: { token: { description: "self-rotate" } }.to_json,
      headers: bearer(agent_token).merge("Content-Type" => "application/json")
    assert_response :forbidden
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
