# Ends a session. Ending a session that does not exist has no effect.
class Authentication::LogOut < ApplicationCommand
  runs_without_organization

  attribute :session_id, :string

  def perform
    Session.where(id: session_id).delete_all if session_id.present?
    success
  end
end
