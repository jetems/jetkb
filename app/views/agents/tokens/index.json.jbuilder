json.array! @tokens do |token|
  json.(token, :id, :description, :permission)
  json.created_at token.created_at.utc
end
