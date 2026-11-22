# typed: strict

# Users and their roles in an organization.
module Accounts
  extend T::Sig

  sig { returns(UseCaseResult::Failure) }
  def self.administrator_not_found = not_found("administrator_not_found", "Administrator not found.")

  sig { returns(UseCaseResult::Failure) }
  def self.invitation_not_found = not_found("invitation_not_found", "Invitation not found.")

  sig { returns(UseCaseResult::Failure) }
  def self.school_not_found = not_found("school_not_found", "School not found.")

  sig { params(code: String, message: String).returns(UseCaseResult::Failure) }
  def self.not_found(code, message)
    UseCaseResult.failure(:not_found, [ UseCaseResult::Error.new(field: nil, code:, message:) ])
  end
  private_class_method :not_found
end
