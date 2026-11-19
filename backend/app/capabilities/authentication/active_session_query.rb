# The session for a session ID from the cookie, or not_logged_in.
class Authentication::ActiveSessionQuery < ApplicationQuery
  runs_without_organization

  attribute :session_id, :string

  ActiveSession = Data.define(:id, :identity_id, :organization_id)

  def perform
    session = Session.find_by(id: session_id) if session_id.present?
    return Authentication.not_logged_in unless session

    success(ActiveSession.new(id: session.id, identity_id: session.identity_id, organization_id: session.organization_id))
  end
end
