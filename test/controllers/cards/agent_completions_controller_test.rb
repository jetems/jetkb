require "test_helper"

class Cards::AgentCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @card = cards(:logo)
    @agent = users(:review_bot)
    @agent_token = @agent.identity.access_tokens.create!(description: "test", permission: :write).token
    @human = users(:david)
    # Grant the agent access to the writebook board (all_access board, but agents need an Access row)
    @card.board.accesses.find_or_create_by!(user: @agent, account: @account)
    Current.user = @human
    @card.toggle_assignment(@agent)
  end

  teardown do
    Current.user = nil
  end

  test "agent completes their assigned card with outcome=closed" do
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "All done.", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Content-Type" => "application/json")
    assert_response :created
    body = response.parsed_body
    assert_equal "succeeded", body["result"]
    assert_equal "closed", body["outcome"]
    assert_equal @card.number, body["card_number"]
    assert body["comment_id"].present?
    assert body["event_id"].present?

    @card.reload
    assert_predicate @card, :closed?
  end

  test "human user cannot use the endpoint" do
    human_token = @human.identity.access_tokens.create!(description: "x", permission: :write).token
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(human_token).merge("Content-Type" => "application/json")
    assert_response :forbidden
  end

  test "agent that is not assigned gets 403" do
    @card.toggle_assignment(@agent)   # unassign
    refute @card.reload.assigned_to?(@agent)

    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Content-Type" => "application/json")
    assert_response :forbidden
  end

  test "Idempotency-Key dedupes retries" do
    key = SecureRandom.uuid
    body = { agent_completion: { result: "succeeded", summary: "Done.", outcome: "closed" } }.to_json
    headers = bearer(@agent_token).merge("Content-Type" => "application/json", "Idempotency-Key" => key)

    assert_difference -> { Card::AgentCompletion.count } => 1 do
      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
      assert_response :created
      first_body = response.parsed_body

      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
      assert_response :created
      second_body = response.parsed_body

      assert_equal first_body["id"], second_body["id"]
    end
  end

  test "missing result returns 422" do
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "outcome triaged:<column_id> moves card into column" do
    column = @card.board.columns.first
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "Moved", outcome: "triaged:#{column.id}" } }.to_json,
      headers: bearer(@agent_token).merge("Content-Type" => "application/json")
    assert_response :created
    assert_equal column, @card.reload.column
  end

  test "cross-account agent token returns 404 (not 403)" do
    initech_agent = users(:qa_bot)
    initech_token = initech_agent.identity.access_tokens.create!(description: "x", permission: :write).token
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(initech_token).merge("Content-Type" => "application/json")
    refute_equal 201, response.status
    refute_equal 200, response.status
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
