# typed: strict

# Promotes an assistant admin to admin, or demotes an admin to assistant admin.
# See Accounts::AdministratorPolicy for who can.
class Accounts::ChangeAdministratorRole < ApplicationCommand
  # The user who makes the change. Nil when the person has no user in the organization.
  attribute :actor_user_id, :string
  attribute :school_administrator_id, :string
  attribute :role, :string

  validates :school_administrator_id, presence: true
  validates :role, inclusion: { in: SchoolAdministrator.roles.keys }

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    school_id = SchoolAdministrator.where(id: school_administrator_id).pick(:school_id)
    administrators = SchoolAdministrator.locked_for_school(school_id).to_a
    target = administrators.find { it.id == school_administrator_id }
    return Accounts.administrator_not_found unless target

    actor = administrators.find { it.user_id == actor_user_id }
    denied = Accounts::AdministratorPolicy.check_change(actor:, target:)
    return denied if denied
    return success(nil) if target.role == role

    before = target.role
    target.update!(role:)
    record_event(target, before)
  end

  private

  sig { params(target: SchoolAdministrator, before: String).returns(UseCaseResult[NilClass]) }
  def record_event(target, before)
    Auditing::RecordEvent.call(
      organization_id:, actor_user_id:, action: "school_administrator.role_changed",
      subject_type: "SchoolAdministrator", subject_id: target.id, details: { "role" => [ before, target.role ] }
    )
  end
end
