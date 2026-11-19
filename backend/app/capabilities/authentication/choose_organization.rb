# Puts a session in one of the organizations where its identity has a user.
class Authentication::ChooseOrganization < ApplicationCommand
  runs_without_organization

  attribute :session_id, :string
  # organization_id (from ApplicationCommand) is the organization to choose.
  validates :organization_id, presence: true

  def perform
    session = Session.lock.active_at(Time.current).find_by(id: session_id)
    return Authentication.not_logged_in unless session

    unless Identity.organization_ids_for(session.identity_id).include?(organization_id)
      return failure(:forbidden, field: :organization_id, code: "not_a_member",
                                 message: "You are not a member of this organization.")
    end

    session.update!(organization_id:)
    success
  end
end
