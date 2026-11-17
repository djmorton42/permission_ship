module Api
  module V1
    class SessionsController < BaseController
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
        render json: { errors: [ { field: nil, code: "rate_limited", message: "Too many login attempts. Try again later." } ] },
               status: :too_many_requests
      }

      def show
        render_result(Authentication::CurrentSessionQuery.call(session_id: session_cookie_id))
      end

      def create
        result = Authentication::LogIn.call(
          email: params[:email], password: params[:password],
          ip_address: request.remote_ip, user_agent: request.user_agent
        )
        return render_failure(result) if result.failure?

        start_session_cookie(result.value.session_id)
        head :no_content
      end

      def destroy
        Authentication::LogOut.call(session_id: session_cookie_id)
        end_session_cookie
        head :no_content
      end
    end
  end
end
