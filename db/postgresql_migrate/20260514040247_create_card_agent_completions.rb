class CreateCardAgentCompletions < ActiveRecord::Migration[8.2]
  def change
    create_table :card_agent_completions, id: :uuid do |t|
      t.references :card,    null: false, foreign_key: true, type: :uuid
      t.references :user,    null: false, foreign_key: true, type: :uuid
      t.references :comment, foreign_key: true, type: :uuid
      t.references :event,   foreign_key: true, type: :uuid
      t.string :idempotency_key
      t.string :result, null: false
      t.jsonb :particulars, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :card_agent_completions,
      %i[ card_id user_id idempotency_key ],
      unique: true,
      where: "idempotency_key IS NOT NULL",
      name: "idx_agent_completions_idempotency"
  end
end
