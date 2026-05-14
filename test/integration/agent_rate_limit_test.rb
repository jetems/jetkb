require "test_helper"

class AgentRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @card = cards(:logo)
    @agent = users(:review_bot)
    @token = @agent.identity.access_tokens.create!(description: "test", permission: :write).token
    @human = users(:david)
    Current.user = @human
    @card.board.accesses.find_or_create_by!(user: @agent, account: @account) unless @card.board.all_access?
    @card.toggle_assignment(@agent)

    # Use an in-memory cache for rack-attack so each test starts fresh
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    # Lower the limit for the test via env var so we don't loop 60 times
    ENV["AGENT_COMPLETION_PER_MINUTE"] = "3"
    # Reload initializer cache (rack-attack reads limit at throttle definition time;
    # we'll handle this by re-requiring the initializer below).
    load Rails.root.join("config/initializers/jetkb_rate_limits.rb")
  end

  teardown do
    Current.user = nil
    ENV.delete("AGENT_COMPLETION_PER_MINUTE")
    # Restore defaults for other tests
    load Rails.root.join("config/initializers/jetkb_rate_limits.rb")
  end

  test "agent_completion N+1 in a minute returns 429" do
    headers = { "Authorization" => "Bearer #{@token}", "Accept" => "application/json", "Content-Type" => "application/json", "Idempotency-Key" => SecureRandom.uuid }
    body = { agent_completion: { result: "succeeded", summary: "x", outcome: "none" } }.to_json

    3.times do |i|
      headers_unique = headers.merge("Idempotency-Key" => SecureRandom.uuid)
      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers_unique
      # Re-assign agent so subsequent calls have an assignee (the controller unassigns on each completion)
      Current.user = @human
      @card.reload.toggle_assignment(@agent) unless @card.reload.assigned_to?(@agent)
    end

    # The 4th call should be 429
    headers_unique = headers.merge("Idempotency-Key" => SecureRandom.uuid)
    post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers_unique
    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?, "Retry-After header should be set"
  end
end
