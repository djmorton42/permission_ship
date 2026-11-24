# typed: strict

# Users and their roles in an organization.
module Accounts
  extend T::Sig

  sig { returns(UseCaseResult::Failure) }
  def self.administrator_not_found = not_found("administrator_not_found", "Administrator not found.")

  sig { returns(UseCaseResult::Failure) }
  def self.invitation_not_found = not_found("invitation_not_found", "Invitation not found.")

  # One error for every link that does not work, so the link does not tell why.
  sig { returns(UseCaseResult::Failure) }
  def self.invitation_link_invalid
    not_found("invitation_link_invalid",
              "This invitation link does not work. It expired, or it was used, resent or revoked. Ask for a new invitation.")
  end

  sig { returns(UseCaseResult::Failure) }
  def self.school_not_found = not_found("school_not_found", "School not found.")

  sig { returns(UseCaseResult::Failure) }
  def self.invitation_closed
    UseCaseResult.failure(:validation, [ UseCaseResult::Error.new(
      field: nil, code: "invitation_closed", message: "This invitation was accepted or revoked."
    ) ])
  end

  # Someone resent or revoked the invitation since the admin loaded it.
  sig { returns(UseCaseResult::Failure) }
  def self.invitation_changed
    UseCaseResult.failure(:conflict, [ UseCaseResult::Error.new(
      field: nil, code: "invitation_changed", message: "This invitation changed. Reload it and try again."
    ) ])
  end

  sig { params(code: String, message: String).returns(UseCaseResult::Failure) }
  def self.not_found(code, message)
    UseCaseResult.failure(:not_found, [ UseCaseResult::Error.new(field: nil, code:, message:) ])
  end
  private_class_method :not_found
end
