json.id @completion.id
json.card_number @completion.card.number
json.result @completion.result
json.outcome @completion.particulars["outcome"]
json.comment_id @completion.comment_id
json.event_id @completion.event_id
json.created_at @completion.created_at.utc
