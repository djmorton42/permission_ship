# Login sessions. Global: a session belongs to an identity, and it records the
# organization the person picked after login (null until they pick one).
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :identity, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
