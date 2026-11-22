# typed: strict

# Removes a user from a school's administrators. The user stays in the organization.
# See Accounts::AdministratorPolicy for who can.
class Accounts::RemoveAdministrator < ApplicationCommand
  # The user who makes the change. Nil when the person has no user in the organization.
  attribute :actor_user_id, :string
  attribute :school_administrator_id, :string

  validates :school_administrator_id, presence: true

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    school_id = SchoolAdministrator.where(id: school_administrator_id).pick(:school_id)
    administrators = SchoolAdministrator.locked_for_school(school_id).to_a
    target = administrators.find { it.id == school_administrator_id }
    return Accounts.administrator_not_found unless target

    actor = administrators.find { it.user_id == actor_user_id }
    denied = Accounts::AdministratorPolicy.check_change(actor:, target:)
    return denied if denied

    target.destroy!
    Auditing::RecordEvent.call(
      organization_id:, actor_user_id:, action: "school_administrator.removed",
      subject_type: "SchoolAdministrator", subject_id: target.id,
      details: { "school_id" => [ target.school_id, nil ], "user_id" => [ target.user_id, nil ],
                 "role" => [ target.role, nil ] }
    )
  end
end
