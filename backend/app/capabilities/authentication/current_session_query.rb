# typed: strict

# What the person sees after login: their user in the session's organization,
# or the organizations to pick from.
# Inputs come from the signed-in session. organization_id is nil until the person picks one.
class Authentication::CurrentSessionQuery < ApplicationQuery
  runs_without_organization

  attribute :identity_id, :string
  validates :identity_id, presence: true

  class SignedIn < T::Struct
    extend T::Sig

    const :current_user, Accounts::CurrentUserQuery::CurrentUser

    sig { params(_options: T.nilable(T::Hash[Symbol, T.anything])).returns(T::Hash[String, T.anything]) }
    def as_json(_options = nil)
      { "status" => "signed_in" }.merge(current_user.as_json)
    end
  end

  class OrganizationRequired < T::Struct
    extend T::Sig

    const :organizations, T::Array[RecordSummary]

    sig { params(_options: T.nilable(T::Hash[Symbol, T.anything])).returns(T::Hash[String, T.anything]) }
    def as_json(_options = nil)
      { status: "organization_required", organizations: }.as_json
    end
  end

  sig { override.returns(UseCaseResult[T.any(SignedIn, OrganizationRequired)]) }
  def perform
    organization_id ? signed_in : pick_organization
  end

  private

  sig { returns(UseCaseResult[SignedIn]) }
  def signed_in
    result = Accounts::CurrentUserQuery.call(organization_id:, identity_id:)
    # The user was removed after login.
    return Authentication.not_logged_in if result.failure?

    success(SignedIn.new(current_user: result.value))
  end

  sig { returns(UseCaseResult[OrganizationRequired]) }
  def pick_organization
    organizations = Organization.where(id: Identity.organization_ids_for(identity_id))
                                .order(:name).pluck(:id, :name)
                                .map { |id, name| RecordSummary.new(id:, name:) }
    success(OrganizationRequired.new(organizations:))
  end
end
