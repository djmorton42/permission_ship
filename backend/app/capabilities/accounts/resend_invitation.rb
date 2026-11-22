# typed: strict

# Sends an open invitation again, with a new link that works for Invitation::LIFETIME.
# Older links stop working.
class Accounts::ResendInvitation < ApplicationCommand
  attribute :actor_user_id, :string
  attribute :invitation_id, :string
  # The version the admin saw. A repeated request has an old version, so it sends nothing.
  attribute :lock_version, :integer

  validates :invitation_id, :lock_version, presence: true

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    invitation = Invitation.lock.find_by(id: invitation_id)
    return Accounts.invitation_not_found unless invitation

    actor = SchoolAdministrator.find_by(school_id: invitation.school_id, user_id: actor_user_id)
    denied = Accounts::AdministratorPolicy.check_invite(actor:)
    return denied if denied
    return Accounts.invitation_closed unless invitation.open?
    return Accounts.invitation_changed unless invitation.lock_version == lock_version

    before = invitation.expires_at
    # The update increments lock_version, so older links stop working.
    invitation.update!(expires_at: Invitation::LIFETIME.from_now)
    InvitationMailer.with(organization_id:, invitation_id: invitation.id).invitation.deliver_later
    Auditing::RecordEvent.call(
      organization_id:, actor_user_id:, action: "invitation.resent", subject_type: "Invitation", subject_id: invitation.id,
      details: { "expires_at" => [ before, invitation.expires_at ] }
    )
  end
end
