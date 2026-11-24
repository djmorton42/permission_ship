# typed: strict

# Makes the invited person an administrator of the school, in the invited role.
# The organization, invitation and lock_version come from the token in the link.
#
# A new person sets their password. A person with an account gives their password.
# The person gets a user in the organization if they do not have one.
# Returns the identity ID, so the caller can start a session.
class Accounts::AcceptInvitation < ApplicationCommand
  attribute :invitation_id, :string
  attribute :lock_version, :integer
  attribute :password, :string
  validates :invitation_id, :lock_version, :password, presence: true

  sig { override.returns(UseCaseResult[String]) }
  def perform
    invitation = Invitation.lock.find_by(id: invitation_id)
    return Accounts.invitation_link_invalid unless invitation&.link_works?(lock_version)

    identity = Authentication::ConfirmIdentity.call(email: invitation.email, password:)
    return identity if identity.is_a?(UseCaseResult::Failure)

    user = User.create_with(organization_id:, name: invitation.name).find_or_create_by!(identity_id: identity.value)
    administrator = SchoolAdministrator.create!(organization_id:, school_id: invitation.school_id, user:, role: invitation.role)
    invitation.update!(accepted_at: Time.current)

    event = Auditing::RecordEvent.call(
      organization_id:, actor_user_id: user.id, action: "invitation.accepted", subject_type: "Invitation",
      subject_id: invitation.id,
      details: { "school_administrator_id" => [ nil, administrator.id ], "role" => [ nil, invitation.role ] }
    )
    event.is_a?(UseCaseResult::Failure) ? event : success(identity.value)
  end
end
