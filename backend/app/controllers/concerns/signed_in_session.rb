# typed: strict

# The signed-in session for API requests. See "Signed-in requests" in architecture.md.
#
# By default, every action needs a session (401 not_logged_in) in an organization
# (403 organization_required). A controller opts out for named actions only:
# - allow_without_session: login and logout.
# - allow_without_organization: the actions that run before the person picks an organization.
#
# Each signed-in request restarts the session's idle timeout (Authentication::RecordSessionActivity).
#
# Commands and queries get the organization from organization_inputs, which takes it
# from the session. An organization ID in the request never replaces it.
# actor_inputs also adds the actor: the session's user in that organization.
module SignedInSession
  extend T::Sig
  extend T::Helpers
  extend ActiveSupport::Concern

  requires_ancestor { Api::V1::BaseController }

  included do
    before_action :require_session
    before_action :require_organization
  end

  module ClassMethods
    extend T::Sig
    extend T::Helpers

    requires_ancestor { T.class_of(ActionController::API) }

    sig { params(options: T.anything).void }
    def allow_without_session(**options)
      skip_before_action :require_session, **options
      skip_before_action :require_organization, **options
    end

    sig { params(options: T.anything).void }
    def allow_without_organization(**options)
      skip_before_action :require_organization, **options
    end
  end

  mixes_in_class_methods(ClassMethods)

  private

  # Set by require_session, which runs before every action that needs a session.
  sig { returns(Authentication::ActiveSessionQuery::ActiveSession) }
  def current_session
    @current_session || raise("current_session is set only for actions that need a session")
  end

  sig { void }
  def require_session
    result = Authentication::ActiveSessionQuery.call(session_id: session_cookie_id)
    return render_failure(result) if result.is_a?(UseCaseResult::Failure)

    @current_session = T.let(result.value, T.nilable(Authentication::ActiveSessionQuery::ActiveSession))
    Authentication::RecordSessionActivity.call(session_id: current_session.id)
  end

  sig { void }
  def require_organization
    render_failure(Authentication.organization_required) unless current_session.organization_id
  end

  # The inputs for a command or query, with the session's organization.
  sig { params(inputs: UseCase::Inputs).returns(UseCase::Inputs) }
  def organization_inputs(inputs = {})
    inputs.to_h.with_indifferent_access.merge(organization_id: current_session.organization_id)
  end

  # organization_inputs, with actor_user_id: the session's user in the organization.
  # Nil when the identity has no user there. Commands then refuse the action.
  sig { params(inputs: UseCase::Inputs).returns(UseCase::Inputs) }
  def actor_inputs(inputs = {})
    actor = Accounts::ActorQuery.call(
      identity_id: current_session.identity_id, organization_id: current_session.organization_id
    )
    raise "ActorQuery failed: #{actor.errors.map(&:message)}" if actor.is_a?(UseCaseResult::Failure)

    organization_inputs(inputs).merge(actor_user_id: actor.value)
  end
end
