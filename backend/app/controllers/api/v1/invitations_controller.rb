# typed: strict

module Api
  module V1
    # An admin invites a person to administer a school.
    class InvitationsController < BaseController
      extend T::Sig

      # Never passes operator_reference. Only the onboarding rake task invites as an operator.
      sig { void }
      def create
        result = Accounts::InviteAdministrator.call(actor_inputs(
          school_id: params[:school_id], email: params[:email], name: params[:name], role: params[:role]
        ))
        return render_failure(result) if result.is_a?(UseCaseResult::Failure)

        render json: { id: result.value }, status: :created
      end
    end
  end
end
