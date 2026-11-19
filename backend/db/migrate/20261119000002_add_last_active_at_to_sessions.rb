# A session ends after 30 minutes without a request. See "Session lifetime" in architecture.md.
# Existing sessions count as active now.
class AddLastActiveAtToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :last_active_at, :datetime, null: false, default: -> { "now()" }
    change_column_default :sessions, :last_active_at, nil
    # The cleanup job deletes idle sessions by last_active_at.
    add_index :sessions, :last_active_at
  end

  def down
    remove_column :sessions, :last_active_at
  end
end
