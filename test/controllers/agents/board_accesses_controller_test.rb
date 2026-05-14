require "test_helper"

class Agents::BoardAccessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @admin = users(:kevin)
    @admin_token = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @agent = users(:review_bot)
    @board = boards(:private)
  end

  test "admin can grant board access" do
    post "#{@account.slug}/agents/#{@agent.id}/board_accesses",
      params: { board_access: { board_id: @board.id } }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    assert_response :created
  end

  test "admin can list grants" do
    Access.find_or_create_by!(user: @agent, board: @board)
    get "#{@account.slug}/agents/#{@agent.id}/board_accesses", headers: bearer(@admin_token)
    assert_response :ok
    assert response.parsed_body.is_a?(Array)
  end

  test "admin can revoke grant" do
    access = Access.find_or_create_by!(user: @agent, board: @board)
    delete "#{@account.slug}/agents/#{@agent.id}/board_accesses/#{@board.id}", headers: bearer(@admin_token)
    assert_response :no_content
    assert_nil Access.find_by(id: access.id)
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
