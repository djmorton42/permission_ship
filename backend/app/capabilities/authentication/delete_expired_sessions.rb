# typed: strict

# Deletes the sessions that have ended: past expires_at, or idle for Session::IDLE_TIMEOUT.
# They cannot be used, so nothing reads them.
# Safe to run more than once. Authentication::DeleteExpiredSessionsJob runs it every hour.
class Authentication::DeleteExpiredSessions < ApplicationCommand
  runs_without_organization

  attribute :as_of, :datetime, default: -> { Time.current }

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    # Nil only when a caller passes nil. The attribute has a default.
    now = T.must(as_of)
    Session.where(expires_at: ..now).or(Session.where(last_active_at: ..(now - Session::IDLE_TIMEOUT))).delete_all
    success(nil)
  end
end
