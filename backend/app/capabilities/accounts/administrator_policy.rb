# typed: strict

# Who can change a school's administrators: an admin of the school, and not for themselves.
#
# Together these rules keep an admin in every school: the actor is an admin who stays.
# Commands lock the school's administrators (SchoolAdministrator.locked_for_school)
# before the check, so two admins cannot demote each other at the same time.
module Accounts::AdministratorPolicy
  extend T::Sig

  # actor is the actor's administrator row in the target's school, or nil.
  # Returns nil when the change is allowed.
  sig { params(actor: T.nilable(SchoolAdministrator), target: SchoolAdministrator).returns(T.nilable(UseCaseResult::Failure)) }
  def self.check_change(actor:, target:)
    denied = check_invite(actor:)
    return denied if denied
    return failure("own_administration", "You cannot change your own role or remove yourself.") if actor&.user_id == target.user_id

    nil
  end

  # Invite a person to administer the school.
  sig { params(actor: T.nilable(SchoolAdministrator)).returns(T.nilable(UseCaseResult::Failure)) }
  def self.check_invite(actor:)
    failure("admin_required", "Only an admin of the school can change its administrators.") unless actor&.admin?
  end

  sig { params(code: String, message: String).returns(UseCaseResult::Failure) }
  def self.failure(code, message)
    UseCaseResult.failure(:forbidden, [ UseCaseResult::Error.new(field: nil, code:, message:) ])
  end
  private_class_method :failure
end
