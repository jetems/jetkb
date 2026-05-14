json.partial! "agents/agent", agent: @agent
json.initial_token do
  json.id @initial_token.id
  json.token @initial_token.token
  json.permission @initial_token.permission
  json.description @initial_token.description
end
