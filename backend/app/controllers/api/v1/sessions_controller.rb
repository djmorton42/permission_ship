# typed: strict

module Api
  module V1
    class SessionsController < BaseController
      extend T::Sig

      # Login and logout work without a session. Reading the session works before
      # the person picks an organization, because it returns the organizations to pick from.
      allow_without_session only: %i[create destroy]
      allow_without_organization only: :show

      rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
        render json: { errors: [ { field: nil, code: "rate_limited", message: "Too many login attempts. Try again later." } ] },
               status: :too_many_requests
      }

      sig { void }
      def show
        render_result(Authentication::CurrentSessionQuery.call(
          identity_id: current_session.identity_id, organization_id: current_session.organization_id
        ))
      end

      sig { void }
      def create
        result = Authentication::LogIn.call(
          email: params[:email], password: params[:password],
          ip_address: request.remote_ip, user_agent: request.user_agent
        )
        return render_failure(result) if result.is_a?(UseCaseResult::Failure)

        start_session_cookie(result.value.session_id, expires_at: result.value.expires_at)
        head :no_content
      end

      sig { void }
      def destroy
        Authentication::LogOut.call(session_id: session_cookie_id)
        end_session_cookie
        head :no_content
      end
    end
  end
end
