require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @owner   = users(:jason)
    @kevin   = users(:kevin)     # admin role
    @member  = users(:jz)
    @owner_token  = @owner.identity.access_tokens.create!(description: "test", permission: :write).token
    @admin_token  = @kevin.identity.access_tokens.create!(description: "test", permission: :write).token
    @member_token = @member.identity.access_tokens.create!(description: "test", permission: :write).token
  end

  test "admin can list agents" do
    get "#{@account.slug}/agents", headers: bearer(@admin_token)
    assert_response :ok
    body = response.parsed_body
    assert body.is_a?(Array)
    assert_includes body.map { |a| a["name"] }, "Review Bot"
  end

  test "member cannot list agents" do
    get "#{@account.slug}/agents", headers: bearer(@member_token)
    assert_response :forbidden
  end

  test "owner can list agents" do
    get "#{@account.slug}/agents", headers: bearer(@owner_token)
    assert_response :ok
  end

  test "admin can create agent and receives initial token" do
    assert_difference -> { @account.users.where(role: :agent).count } => 1 do
      post "#{@account.slug}/agents",
        params: { agent: { name: "New Bot", slug: "new-bot", webhook_url: "https://example.com/hook" } }.to_json,
        headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "new-bot", body["slug"]
    assert_equal "new-bot@agent.local", body["email_address"]
    assert_equal "https://example.com/hook", body["webhook_url"]
    assert body.dig("initial_token", "token").present?
  end

  test "agent slug must be unique within Identity emails" do
    post "#{@account.slug}/agents",
      params: { agent: { name: "Dup", slug: "review-bot" } }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "agent slug format is enforced" do
    post "#{@account.slug}/agents",
      params: { agent: { name: "Bad", slug: "BadCase!" } }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "show returns single agent" do
    get "#{@account.slug}/agents/#{users(:review_bot).id}", headers: bearer(@admin_token)
    assert_response :ok
    assert_equal "Review Bot", response.parsed_body["name"]
  end

  test "patch can change name but not slug" do
    agent = users(:review_bot)
    original_email = agent.identity.email_address
    patch "#{@account.slug}/agents/#{agent.id}",
      params: { agent: { name: "Renamed Bot", slug: "different-slug" } }.to_json,
      headers: bearer(@admin_token).merge("Content-Type" => "application/json")
    assert_response :ok
    assert_equal "Renamed Bot", agent.reload.name
    assert_equal original_email, agent.identity.reload.email_address
  end

  test "admin can delete agent and cascade Identity + tokens" do
    agent = users(:qa_bot)
    agent.identity.access_tokens.create!(description: "x", permission: :write)
    other_admin = users(:mike)
    other_admin_token = other_admin.identity.access_tokens.create!(description: "x", permission: :write).token

    delete "#{accounts(:initech).slug}/agents/#{agent.id}",
      headers: bearer(other_admin_token).merge("Accept" => "application/json")
    assert_response :no_content
    assert_nil Identity.find_by(email_address: "qa-bot@agent.local")
  end

  test "cross-account access returns 404" do
    other_admin_token = users(:mike).identity.access_tokens.create!(description: "x", permission: :write).token
    # Mike is admin on Initech; he tries to read a 37s agent
    get "#{accounts(:initech).slug}/agents/#{users(:review_bot).id}",
      headers: bearer(other_admin_token)
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    end
end
