require "test_helper"

class Card::AgentCompletionTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
    @agent_identity = Identity.create!(email_address: "completion-bot-#{SecureRandom.hex(4)}@agent.local")
    @agent = @card.account.users.create!(role: :agent, name: "Completion Bot", identity: @agent_identity, active: true)
    @human = users(:david)
    Current.user = @human
    @card.toggle_assignment(@agent)   # assign agent
  end

  teardown do
    Current.user = nil
  end

  test "record! writes comment, closes card, unassigns agent, emits event" do
    completion = Card::AgentCompletion.record!(
      card: @card,
      agent: @agent,
      result: "succeeded",
      summary: "Looks great.",
      outcome: "closed",
      idempotency_key: SecureRandom.uuid
    )

    assert_predicate completion, :persisted?
    assert_equal "succeeded", completion.result
    @card.reload
    assert_predicate @card, :closed?
    refute @card.assigned_to?(@agent)
    assert_equal 1, @card.comments.where(creator: @agent).count
    last_event = Event.where(eventable: @card).order(:created_at).last
    assert_equal "card_agent_completed", last_event.action
    assert_equal @agent.id, last_event.creator_id
  end

  test "non-assignee raises NotAssigned" do
    @card.toggle_assignment(@agent)   # unassign first
    @card.reload
    refute @card.assigned_to?(@agent)

    assert_raises(Card::AgentCompletion::NotAssigned) do
      Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "x", outcome: "closed")
    end
  end

  test "same idempotency_key returns first record without side effects" do
    key = SecureRandom.uuid
    first  = Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "First",  outcome: "closed", idempotency_key: key)
    second = Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "Second", outcome: "closed", idempotency_key: key)

    assert_equal first.id, second.id
    assert_equal 1, @card.reload.comments.where(creator: @agent).count, "Second call must not write another comment"
  end

  test "result=failed with outcome nil leaves card open" do
    Card::AgentCompletion.record!(card: @card, agent: @agent, result: "failed", summary: "Broken.", outcome: nil)
    refute_predicate @card.reload, :closed?
  end

  test "outcome triaged:<column_id> moves card into that column" do
    column = @card.board.columns.first
    refute_nil column

    Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "Moved.", outcome: "triaged:#{column.id}")

    assert_equal column, @card.reload.column
  end

  test "artifacts limited to 10" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Card::AgentCompletion.record!(
        card: @card, agent: @agent, result: "succeeded", summary: "Many",
        outcome: "closed",
        artifacts: 11.times.map { |i| { "label" => "a#{i}", "url" => "https://example.com/#{i}" } }
      )
    end
  end
end
