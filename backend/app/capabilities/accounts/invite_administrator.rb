# typed: strict

# Invites a person by email to administer a school, and sends the invitation email.
#
# The inviter is an admin of the school (actor_user_id), or the operations team
# (operator_reference) for a school's first admin. Only the rake task
# onboarding:invite_school_admin sets operator_reference. The API never does.
class Accounts::InviteAdministrator < ApplicationCommand
  attribute :actor_user_id, :string
  attribute :operator_reference, :string
  attribute :school_id, :string
  attribute :email, :string
  attribute :name, :string
  attribute :role, :string

  validates :school_id, :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: Invitation.roles.keys }
  validate :one_inviter

  sig { returns(T.nilable(String)) }
  def email = super&.strip&.downcase

  sig { override.returns(UseCaseResult[String]) }
  def perform
    return Accounts.school_not_found unless School.exists?(id: school_id)

    if operator_reference.blank?
      actor = SchoolAdministrator.find_by(school_id:, user_id: actor_user_id)
      denied = Accounts::AdministratorPolicy.check_invite(actor:)
      return denied if denied
    end
    return already_administrator if administrator?

    invitation = create_invitation
    return invitation_open unless invitation

    InvitationMailer.with(organization_id:, invitation_id: invitation.id).invitation.deliver_later
    record_event(invitation).then { it.is_a?(UseCaseResult::Failure) ? it : success(invitation.id) }
  end

  private

  sig { returns(T::Boolean) }
  def administrator?
    identity_id = Authentication::IdentityIdQuery.call(email:).value
    return false unless identity_id

    SchoolAdministrator.joins(:user).exists?(school_id:, users: { identity_id: })
  end

  # Nil when an invitation for the person and school is open (index_invitations_one_open).
  sig { returns(T.nilable(Invitation)) }
  def create_invitation
    # A savepoint, so the unique violation does not end the command's transaction.
    Invitation.transaction(requires_new: true) do
      Invitation.create!(organization_id:, school_id:, email:, name:, role:, invited_by_user_id: actor_user_id.presence,
                         operator_reference: operator_reference.presence, expires_at: Invitation::LIFETIME.from_now)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  sig { params(invitation: Invitation).returns(UseCaseResult[NilClass]) }
  def record_event(invitation)
    Auditing::RecordEvent.call(
      organization_id:, actor_user_id: invitation.invited_by_user_id, operator_reference: invitation.operator_reference,
      action: "invitation.created", subject_type: "Invitation", subject_id: invitation.id,
      details: { "school_id" => [ nil, school_id ], "email" => [ nil, email ], "role" => [ nil, role ] }
    )
  end

  sig { void }
  def one_inviter
    return unless actor_user_id.present? && operator_reference.present?

    errors.add(:base, :one_inviter_required, message: "Give an admin or an operator as the inviter, not both.")
  end

  sig { returns(UseCaseResult::Failure) }
  def already_administrator
    failure(:validation, field: :email, code: "already_administrator",
                         message: "This person already administers the school. Change their role instead.")
  end

  sig { returns(UseCaseResult::Failure) }
  def invitation_open
    failure(:conflict, field: :email, code: "invitation_open",
                       message: "This person has an open invitation to the school. Resend it instead.")
  end
end
