# Deletes the sessions that have ended. They cannot be used, so nothing reads them.
# Safe to run more than once. Authentication::DeleteExpiredSessionsJob runs it every hour.
class Authentication::DeleteExpiredSessions < ApplicationCommand
  runs_without_organization

  attribute :as_of, :datetime, default: -> { Time.current }

  def perform
    Session.where(expires_at: ..as_of).delete_all
    success
  end
end
