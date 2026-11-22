# typed: strict

# Users and their roles in an organization.
module Accounts
  extend T::Sig

  sig { returns(UseCaseResult::Failure) }
  def self.administrator_not_found
    UseCaseResult.failure(:not_found, [ UseCaseResult::Error.new(field: nil, code: "administrator_not_found",
                                                                 message: "Administrator not found.") ])
  end
end
