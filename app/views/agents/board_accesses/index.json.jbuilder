json.array! @accesses do |access|
  json.id access.id
  json.board_id access.board_id
  json.board_name access.board.name
end
