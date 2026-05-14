require "test_helper"

class AgentSettingTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @identity = Identity.create!(email_address: "setting-bot-#{SecureRandom.hex(4)}@agent.local")
    @agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity, active: true)
  end

  test "belongs to a user" do
    setting = AgentSetting.create!(user: @agent, webhook_url: "https://example.com/h", all_access_boards: false)
    assert_equal @agent, setting.user
  end

  test "all_access_boards defaults to true" do
    setting = AgentSetting.create!(user: @agent)
    assert_equal true, setting.all_access_boards
  end

  test "user_id is unique" do
    AgentSetting.create!(user: @agent)
    assert_raises(ActiveRecord::RecordNotUnique) do
      AgentSetting.create!(user: @agent)
    end
  end
end
