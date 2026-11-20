# typed: strict

# The session for a session ID from the cookie, or not_logged_in.
# A session that has ended (expires_at) counts as not logged in.
class Authentication::ActiveSessionQuery < ApplicationQuery
  runs_without_organization

  attribute :session_id, :string

  class ActiveSession < T::Struct
    const :id, String
    const :identity_id, String
    const :organization_id, T.nilable(String)
  end

  sig { override.returns(UseCaseResult[ActiveSession]) }
  def perform
    session = Session.active_at(Time.current).find_by(id: session_id) if session_id.present?
    return Authentication.not_logged_in unless session

    success(ActiveSession.new(id: session.id, identity_id: session.identity_id, organization_id: session.organization_id))
  end
end
