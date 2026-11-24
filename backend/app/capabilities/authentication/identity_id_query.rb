# typed: strict

# The ID of the identity with the email address, or nil.
class Authentication::IdentityIdQuery < ApplicationQuery
  runs_without_organization

  attribute :email, :string
  validates :email, presence: true

  sig { override.returns(UseCaseResult[T.nilable(String)]) }
  def perform
    # Identity normalizes the email in the query too.
    success(Identity.where(email:).pick(:id))
  end
end
