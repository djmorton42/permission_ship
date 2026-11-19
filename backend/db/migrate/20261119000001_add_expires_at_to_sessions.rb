# A session ends at expires_at. See "Session lifetime" in architecture.md.
# Existing sessions end now: their people log in again.
class AddExpiresAtToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :expires_at, :datetime, null: false, default: -> { "now()" }
    change_column_default :sessions, :expires_at, nil
    # The cleanup job deletes sessions by expires_at.
    add_index :sessions, :expires_at
  end

  def down
    remove_column :sessions, :expires_at
  end
end
