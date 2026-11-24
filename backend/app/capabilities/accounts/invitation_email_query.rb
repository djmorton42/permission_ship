# typed: strict

# What the invitation email shows. Not found when the invitation is no longer open.
class Accounts::InvitationEmailQuery < ApplicationQuery
  attribute :invitation_id, :string
  validates :invitation_id, presence: true

  class InvitationEmail < T::Struct
    const :invitation_id, String
    const :email, String
    const :name, String
    const :role, String
    const :school_name, String
    # Nil when the operations team sent the invitation.
    const :inviter_name, T.nilable(String)
    const :expires_at, ActiveSupport::TimeWithZone
    const :lock_version, Integer
  end

  sig { override.returns(UseCaseResult[InvitationEmail]) }
  def perform
    invitation = Invitation.preload(:school, :invited_by_user).find_by(id: invitation_id)
    return Accounts.invitation_not_found unless invitation&.open?

    # T.must: school_id is NOT NULL with a foreign key, but tapioca types belongs_to as nilable.
    school = T.must(invitation.school)
    success(InvitationEmail.new(
      invitation_id: invitation.id, email: invitation.email, name: invitation.name, role: invitation.role,
      school_name: school.name, inviter_name: invitation.invited_by_user&.name,
      expires_at: invitation.expires_at, lock_version: invitation.lock_version
    ))
  end
end
