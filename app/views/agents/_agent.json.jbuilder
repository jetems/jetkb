setting = AgentSetting.find_by(user: agent) || AgentSetting.new(user: agent)
permission = agent.identity&.access_tokens&.order(:created_at)&.last&.permission

json.cache! [ agent, setting ] do
  json.(agent, :id, :name, :active)
  json.slug agent.identity&.email_address&.split("@")&.first
  json.email_address agent.identity&.email_address
  json.webhook_url setting.webhook_url
  json.all_access_boards setting.all_access_boards
  json.permission permission
  json.is_agent true
  json.created_at agent.created_at.utc
  json.updated_at agent.updated_at.utc
  json.assigned_cards_count agent.assigned_cards.count
  json.completed_cards_count Event.where(creator: agent, action: "card_agent_completed").count
  json.url agent_url(agent)
end
