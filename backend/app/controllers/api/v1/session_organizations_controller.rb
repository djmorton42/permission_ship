module Api
  module V1
    # The person picks an organization after login.
    class SessionOrganizationsController < BaseController
      def create
        render_result(Authentication::ChooseOrganization.call(
          session_id: session_cookie_id, organization_id: params[:organization_id]
        ))
      end
    end
  end
end
