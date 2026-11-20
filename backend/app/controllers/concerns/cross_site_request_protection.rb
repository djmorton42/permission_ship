# typed: strict

# Protects cookie-authenticated writes from other sites, including login CSRF.
# SameSite=Lax stops the browser from sending the session cookie with a cross-site
# POST, but it does not stop the response from setting a new cookie.
#
# Every request except GET, HEAD and OPTIONS must:
# - come from the API's own origin or an origin in config.x.allowed_origins (403 otherwise).
#   Browsers send Origin with every such request. A request without one is rejected.
# - send JSON when it is a POST, PUT or PATCH (415 otherwise). An HTML form cannot send JSON,
#   and a cross-origin fetch with JSON needs a CORS preflight that other origins do not pass.
# See "Sessions and CSRF" in architecture.md.
module CrossSiteRequestProtection
  extend T::Sig
  extend T::Helpers
  extend ActiveSupport::Concern

  requires_ancestor { ActionController::API }

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze
  BODY_METHODS = %w[POST PUT PATCH].freeze

  included do
    before_action :reject_cross_site_request
  end

  private

  sig { void }
  def reject_cross_site_request
    return if SAFE_METHODS.include?(request.method)

    unless allowed_origin?
      return render_request_error(:forbidden, "origin_not_allowed", "This request must come from the Permission Ship app.")
    end

    if BODY_METHODS.include?(request.method) && request.media_type != Mime[:json].to_s
      render_request_error(:unsupported_media_type, "json_required", "Send the request as JSON.")
    end
  end

  sig { returns(T::Boolean) }
  def allowed_origin?
    origin = request.origin
    origin == request.base_url || Rails.configuration.x.allowed_origins.include?(origin)
  end

  sig { params(status: Symbol, code: String, message: String).void }
  def render_request_error(status, code, message)
    render json: { errors: [ { field: nil, code:, message: } ] }, status:
  end
end
