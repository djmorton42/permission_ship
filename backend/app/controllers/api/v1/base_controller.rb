# typed: strict

module Api
  module V1
    # Base class for all versioned API controllers.
    # Maps a UseCaseResult to an HTTP response. See "Results and errors" in architecture.md.
    class BaseController < ApplicationController
      extend T::Sig
      include ActionController::Cookies
      include SessionCookie
      include CrossSiteRequestProtection
      include SignedInSession

      # Responses hold a person's data. Browsers and proxies must not keep a copy,
      # for example on a shared school computer after logout.
      before_action :no_store

      FAILURE_STATUSES = T.let({
        validation: :unprocessable_content,
        unauthenticated: :unauthorized,
        forbidden: :forbidden,
        not_found: :not_found,
        conflict: :conflict
      }.freeze, T::Hash[Symbol, Symbol])

      private

      sig { params(result: UseCaseResult[T.anything], status: Symbol).void }
      def render_result(result, status: :ok)
        return render_failure(result) if result.is_a?(UseCaseResult::Failure)

        case (value = result.value)
        when nil then head status == :ok ? :no_content : status
        else render json: value, status:
        end
      end

      sig { params(failure: UseCaseResult::Failure).void }
      def render_failure(failure)
        render json: { errors: failure.errors.map(&:to_h) }, status: FAILURE_STATUSES.fetch(failure.category)
      end
    end
  end
end
