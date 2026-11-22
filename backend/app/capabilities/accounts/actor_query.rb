# typed: strict

# The ID of the identity's user in the organization: the actor for authorization.
# Nil when the identity has no user there (for example, after the user was removed).
class Accounts::ActorQuery < ApplicationQuery
  attribute :identity_id, :string
  validates :identity_id, presence: true

  sig { override.returns(UseCaseResult[T.nilable(String)]) }
  def perform
    # Row-level security limits users to the organization.
    success(User.where(identity_id:).pick(:id))
  end
end
