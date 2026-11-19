# The signed-in session for API requests. See "Signed-in requests" in architecture.md.
#
# By default, every action needs a session (401 not_logged_in) in an organization
# (403 organization_required). A controller opts out for named actions only:
# - allow_without_session: login and logout.
# - allow_without_organization: the actions that run before the person picks an organization.
#
# Commands and queries get the organization from organization_inputs, which takes it
# from the session. An organization ID in the request never replaces it.
module SignedInSession
  extend ActiveSupport::Concern

  included do
    before_action :require_session
    before_action :require_organization
  end

  class_methods do
    def allow_without_session(**options)
      skip_before_action :require_session, **options
      skip_before_action :require_organization, **options
    end

    def allow_without_organization(**options)
      skip_before_action :require_organization, **options
    end
  end

  private

  # An Authentication::ActiveSessionQuery::ActiveSession. Set by require_session.
  attr_reader :current_session

  def require_session
    result = Authentication::ActiveSessionQuery.call(session_id: session_cookie_id)
    return render_failure(result) if result.failure?

    @current_session = result.value
  end

  def require_organization
    render_failure(Authentication.organization_required) unless current_session.organization_id
  end

  # The inputs for a command or query, with the session's organization.
  def organization_inputs(inputs = {})
    inputs.to_h.with_indifferent_access.merge(organization_id: current_session.organization_id)
  end
end
