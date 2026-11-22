# typed: strict

module Api
  module V1
    # An admin changes the role of a school's administrator, or removes one.
    class SchoolAdministratorsController < BaseController
      extend T::Sig

      sig { void }
      def update
        render_result(Accounts::ChangeAdministratorRole.call(
          actor_inputs(school_administrator_id: params[:id], role: params[:role])
        ))
      end

      sig { void }
      def destroy
        render_result(Accounts::RemoveAdministrator.call(actor_inputs(school_administrator_id: params[:id])))
      end
    end
  end
end
