# What the person sees after login: their user in the session's organization,
# or the organizations to pick from.
# Inputs come from the signed-in session. organization_id is nil until the person picks one.
class Authentication::CurrentSessionQuery < ApplicationQuery
  runs_without_organization

  attribute :identity_id, :string
  validates :identity_id, presence: true

  SignedIn = Data.define(:current_user) do
    def as_json(*)
      { status: "signed_in" }.merge(current_user.as_json).as_json
    end
  end

  OrganizationRequired = Data.define(:organizations) do
    def as_json(*)
      { status: "organization_required", organizations: }.as_json
    end
  end

  def perform
    organization_id ? signed_in : pick_organization
  end

  private

  def signed_in
    result = Accounts::CurrentUserQuery.call(organization_id:, identity_id:)
    # The user was removed after login.
    return Authentication.not_logged_in if result.failure?

    success(SignedIn.new(current_user: result.value))
  end

  def pick_organization
    organizations = Organization.where(id: Identity.organization_ids_for(identity_id))
                                .order(:name).pluck(:id, :name)
                                .map { |id, name| RecordSummary.new(id:, name:) }
    success(OrganizationRequired.new(organizations:))
  end
end
