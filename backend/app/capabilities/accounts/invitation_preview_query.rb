# typed: strict

# What the invitation page shows before the person accepts. The organization, invitation
# and lock_version come from the token in the link (Accounts::InvitationToken).
class Accounts::InvitationPreviewQuery < ApplicationQuery
  attribute :invitation_id, :string
  attribute :lock_version, :integer
  validates :invitation_id, :lock_version, presence: true

  class InvitationPreview < T::Struct
    extend T::Sig

    const :email, String
    const :name, String
    const :role, String
    const :school_name, String
    # Nil when the operations team sent the invitation.
    const :inviter_name, T.nilable(String)
    # True when the email has an identity. The person then gives their password, not a new one.
    const :has_account, T::Boolean

    sig { params(_options: T.nilable(T::Hash[Symbol, T.anything])).returns(T::Hash[String, T.anything]) }
    def as_json(_options = nil) = serialize
  end

  sig { override.returns(UseCaseResult[InvitationPreview]) }
  def perform
    invitation = Invitation.preload(:school, :invited_by_user).find_by(id: invitation_id)
    return Accounts.invitation_link_invalid unless invitation&.link_works?(lock_version)

    # T.must: school_id is NOT NULL with a foreign key, but tapioca types belongs_to as nilable.
    school = T.must(invitation.school)
    success(InvitationPreview.new(
      email: invitation.email, name: invitation.name, role: invitation.role, school_name: school.name,
      inviter_name: invitation.invited_by_user&.name,
      has_account: !Authentication::IdentityIdQuery.call(email: invitation.email).value.nil?
    ))
  end
end
