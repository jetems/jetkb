json.cache! user do
  json.(user, :id, :name, :role, :active)
  json.is_agent user.agent?

  json.email_address user.identity&.email_address
  json.created_at user.created_at.utc

  json.url user_url(user)
  json.avatar_url user_avatar_url(user)
end
