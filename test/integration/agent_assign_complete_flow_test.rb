require "test_helper"

class AgentAssignCompleteFlowTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @card = cards(:logo)
    @board = @card.board
    @admin = users(:kevin)        # admin role
    @admin_token = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @human = users(:david)
    Current.user = @human

    # Subscribe a webhook on the agent-relevant actions
    @webhook = @board.webhooks.create!(
      name: "Agent flow webhook",
      url: "https://hook.example.com/jetkb",
      subscribed_actions: [ "card_assigned", "card_assigned_to_agent", "card_agent_completed" ]
    )
  end

  teardown do
    Current.user = nil
  end

  test "full loop: admin creates agent -> assigns card -> agent completes -> webhooks fire" do
    # Step 1: admin creates an agent
    assert_difference -> { @account.users.where(role: :agent).count } => 1 do
      post "#{@account.slug}/agents",
        params: { agent: { name: "Flow Bot", slug: "flow-bot-#{SecureRandom.hex(4)}" } }.to_json,
        headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    end
    assert_response :created

    created = response.parsed_body
    agent_id = created["id"]
    agent_token = created.dig("initial_token", "token")
    refute_nil agent_token, "initial token must be returned"

    # Step 2: admin assigns card to the agent
    # The agent was just created and after_create_commit granted access to all_access boards.
    # We need to reload the board users to reflect the new access record.
    assert_difference -> { @card.reload.assignments.count } => 1 do
      post "#{@account.slug}/cards/#{@card.number}/assignments",
        params: { assignee_id: agent_id }.to_json,
        headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    end

    # Step 3: verify both card_assigned and card_assigned_to_agent events were emitted
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_assigned"
    assert_includes actions, "card_assigned_to_agent"

    # Step 4: verify webhook dispatch jobs were enqueued for the agent webhook
    # Event::WebhookDispatchJob is enqueued after_create_commit on each Event.
    # The test adapter captures these; access it directly via ActiveJob::Base.queue_adapter.
    enqueued_job_classes = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j[:job] }
    assert_includes enqueued_job_classes, Event::WebhookDispatchJob,
      "Webhook dispatch jobs must be enqueued for assignment events"

    # Step 5: agent reports completion via the sugar endpoint
    agent_user = @account.users.find(agent_id)
    Current.user = agent_user   # agent_completion lookup uses Current.user via token auth

    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "All done.", outcome: "closed" } }.to_json,
      headers: bearer(agent_token).merge("Content-Type" => "application/json", "Idempotency-Key" => SecureRandom.uuid)
    assert_response :created

    Current.user = nil

    # Step 6: verify final state
    @card.reload
    assert_predicate @card, :closed?
    agent = @account.users.find(agent_id)
    refute @card.assigned_to?(agent), "Agent must be unassigned after completion"

    # The card_agent_completed event must be the last event
    last_event = Event.where(eventable: @card).order(:created_at).last
    assert_equal "card_agent_completed", last_event.action
    assert_equal agent_id, last_event.creator_id

    # The agent's comment must exist
    agent_comments = @card.comments.where(creator_id: agent_id)
    assert_equal 1, agent_comments.count
    assert_match(/All done\./, agent_comments.first.body.to_plain_text)
  end

  test "outcome triaged moves the card into the target column" do
    # Build a quick agent + assignment
    post "#{@account.slug}/agents",
      params: { agent: { name: "Triage Bot", slug: "triage-bot-#{SecureRandom.hex(4)}" } }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    agent_id = response.parsed_body["id"]
    agent_token = response.parsed_body.dig("initial_token", "token")

    post "#{@account.slug}/cards/#{@card.number}/assignments",
      params: { assignee_id: agent_id }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")

    target_column = @card.board.columns.first
    refute_nil target_column

    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "Moved", outcome: "triaged:#{target_column.id}" } }.to_json,
      headers: bearer(agent_token).merge("Content-Type" => "application/json", "Idempotency-Key" => SecureRandom.uuid)
    assert_response :created

    assert_equal target_column, @card.reload.column
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
