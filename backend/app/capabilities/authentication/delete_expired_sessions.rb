# Deletes the sessions that have ended: past expires_at, or idle for Session::IDLE_TIMEOUT.
# They cannot be used, so nothing reads them.
# Safe to run more than once. Authentication::DeleteExpiredSessionsJob runs it every hour.
class Authentication::DeleteExpiredSessions < ApplicationCommand
  runs_without_organization

  attribute :as_of, :datetime, default: -> { Time.current }

  def perform
    Session.where(expires_at: ..as_of).or(Session.where(last_active_at: ..(as_of - Session::IDLE_TIMEOUT))).delete_all
    success
  end
end
