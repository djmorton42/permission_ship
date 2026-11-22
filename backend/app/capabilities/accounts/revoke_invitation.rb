# typed: strict

# Closes an open invitation. Its link stops working, and an email not sent yet is not sent.
class Accounts::RevokeInvitation < ApplicationCommand
  attribute :actor_user_id, :string
  attribute :invitation_id, :string

  validates :invitation_id, presence: true

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    invitation = Invitation.lock.find_by(id: invitation_id)
    return Accounts.invitation_not_found unless invitation

    actor = SchoolAdministrator.find_by(school_id: invitation.school_id, user_id: actor_user_id)
    denied = Accounts::AdministratorPolicy.check_invite(actor:)
    return denied if denied
    return Accounts.invitation_closed unless invitation.open?

    invitation.update!(revoked_at: Time.current)
    Auditing::RecordEvent.call(
      organization_id:, actor_user_id:, action: "invitation.revoked", subject_type: "Invitation", subject_id: invitation.id,
      details: { "revoked_at" => [ nil, invitation.revoked_at ] }
    )
  end
end
