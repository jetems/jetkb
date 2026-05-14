require "test_helper"

class Card::AgentAssignmentFanoutTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @card = cards(:logo)
    @human = users(:jz)
    @agent = users(:review_bot)
    Current.user = users(:david)
  end

  teardown do
    Current.user = nil
  end

  test "assigning a human does NOT emit card_assigned_to_agent" do
    @card.toggle_assignment(@human)
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_assigned"
    refute_includes actions, "card_assigned_to_agent"
  end

  test "assigning an agent emits both card_assigned and card_assigned_to_agent" do
    @card.board.accesses.find_or_create_by!(user: @agent, account: @account) unless @card.board.all_access?
    @card.toggle_assignment(@agent)
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_assigned"
    assert_includes actions, "card_assigned_to_agent"
  end

  test "agent fanout event has same assignee particulars" do
    @card.board.accesses.find_or_create_by!(user: @agent, account: @account) unless @card.board.all_access?
    @card.toggle_assignment(@agent)
    fanout = Event.where(eventable: @card, action: "card_assigned_to_agent").last
    refute_nil fanout
    assignee_ids = fanout.particulars["assignee_ids"] || fanout.particulars[:assignee_ids]
    assert_equal [ @agent.id ], assignee_ids
  end

  test "unassigning an agent does NOT emit card_assigned_to_agent (just card_unassigned)" do
    @card.board.accesses.find_or_create_by!(user: @agent, account: @account) unless @card.board.all_access?
    @card.toggle_assignment(@agent)   # assign
    Event.where(eventable: @card).delete_all  # reset

    @card.toggle_assignment(@agent)   # unassign
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_unassigned"
    refute_includes actions, "card_assigned_to_agent"
  end
end
