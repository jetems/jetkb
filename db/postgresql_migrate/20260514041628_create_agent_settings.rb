class CreateAgentSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :agent_settings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string  :webhook_url
      t.boolean :all_access_boards, default: true, null: false
      t.timestamps
    end
  end
end
