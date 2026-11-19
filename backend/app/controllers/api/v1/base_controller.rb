module Api
  module V1
    # Base class for all versioned API controllers.
    # Maps a UseCaseResult to an HTTP response. See "Results and errors" in architecture.md.
    class BaseController < ApplicationController
      include ActionController::Cookies
      include SessionCookie
      include CrossSiteRequestProtection

      # Responses hold a person's data. Browsers and proxies must not keep a copy,
      # for example on a shared school computer after logout.
      before_action :no_store

      FAILURE_STATUSES = {
        validation: :unprocessable_content,
        unauthenticated: :unauthorized,
        forbidden: :forbidden,
        not_found: :not_found,
        conflict: :conflict
      }.freeze

      private

      def render_result(result, status: :ok)
        return render_failure(result) if result.failure?

        if result.value.nil?
          head status == :ok ? :no_content : status
        else
          render json: result.value, status:
        end
      end

      def render_failure(result)
        render json: { errors: result.errors.map(&:to_h) }, status: FAILURE_STATUSES.fetch(result.category)
      end
    end
  end
end
