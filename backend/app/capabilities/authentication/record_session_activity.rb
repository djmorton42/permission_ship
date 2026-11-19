# Records a request in the session, so the idle timeout (Session::IDLE_TIMEOUT) starts again.
# SignedInSession runs it for every signed-in request, including GET requests.
class Authentication::RecordSessionActivity < ApplicationCommand
  runs_without_organization

  attribute :session_id, :string
  attribute :as_of, :datetime, default: -> { Time.current }
  validates :session_id, presence: true

  def perform
    Session.where(id: session_id).update_all(last_active_at: as_of)
    success
  end
end
