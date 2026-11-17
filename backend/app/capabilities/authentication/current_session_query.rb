# What the person sees after login: their user in the session's organization,
# or the organizations to pick from.
class Authentication::CurrentSessionQuery < ApplicationQuery
  runs_without_organization

  attribute :session_id, :string

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
    session = Session.find_by(id: session_id) if session_id.present?
    return Authentication.not_logged_in unless session

    if session.organization_id
      signed_in(session)
    else
      pick_organization(session)
    end
  end

  private

  def signed_in(session)
    result = Accounts::CurrentUserQuery.call(organization_id: session.organization_id, identity_id: session.identity_id)
    # The user was removed after login.
    return Authentication.not_logged_in if result.failure?

    success(SignedIn.new(current_user: result.value))
  end

  def pick_organization(session)
    organizations = Organization.where(id: Identity.organization_ids_for(session.identity_id))
                                .order(:name).pluck(:id, :name)
                                .map { |id, name| RecordSummary.new(id:, name:) }
    success(OrganizationRequired.new(organizations:))
  end
end
