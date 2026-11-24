# typed: strict

module Api
  module V1
    # The invitation page: shows an invitation, and accepts it. The person is not logged in.
    #
    # The token from the link comes in the JSON body, also for the preview. Reason: a token
    # in a URL goes to server logs and browser history.
    class InvitationAcceptancesController < BaseController
      extend T::Sig

      allow_without_session only: %i[preview create]

      # A person with an account gives their password here, so limit attempts as for login.
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
        render json: { errors: [ { field: nil, code: "rate_limited", message: "Too many attempts. Try again later." } ] },
               status: :too_many_requests
      }

      sig { void }
      def preview
        link = token_payload
        return render_failure(Accounts.invitation_link_invalid) unless link

        render_result(Accounts::InvitationPreviewQuery.call(
          organization_id: link.organization_id, invitation_id: link.invitation_id, lock_version: link.lock_version
        ))
      end

      # Accepts, then logs the person in to the organization. A session that the browser
      # had before ends, so the browser has one session.
      sig { void }
      def create
        link = token_payload
        return render_failure(Accounts.invitation_link_invalid) unless link

        accepted = Accounts::AcceptInvitation.call(
          organization_id: link.organization_id, invitation_id: link.invitation_id, lock_version: link.lock_version,
          password: params[:password]
        )
        return render_failure(accepted) if accepted.is_a?(UseCaseResult::Failure)

        Authentication::LogOut.call(session_id: session_cookie_id)
        started = Authentication::StartSession.call(
          identity_id: accepted.value, organization_id: link.organization_id,
          ip_address: request.remote_ip, user_agent: request.user_agent
        )
        return render_failure(started) if started.is_a?(UseCaseResult::Failure)

        start_session_cookie(started.value.session_id, expires_at: started.value.expires_at)
        head :no_content
      end

      private

      sig { returns(T.nilable(Accounts::InvitationToken::Payload)) }
      def token_payload
        token = params[:token]
        token.is_a?(String) ? Accounts::InvitationToken.read(token) : nil
      end
    end
  end
end
