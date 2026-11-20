# typed: strict

module Api
  module V1
    # The person picks an organization after login.
    class SessionOrganizationsController < BaseController
      extend T::Sig

      allow_without_organization only: :create

      # The only action that takes an organization ID from the request.
      # ChooseOrganization checks that the identity has a user there.
      sig { void }
      def create
        render_result(Authentication::ChooseOrganization.call(
          session_id: current_session.id, organization_id: params[:organization_id]
        ))
      end
    end
  end
end
