# typed: strict

# The login session ID, in a signed cookie that JavaScript cannot read.
# SameSite=Lax: browsers do not send the cookie with cross-site POST requests.
# The cookie expires when the session ends, so the browser deletes it.
module SessionCookie
  extend T::Sig
  extend T::Helpers

  requires_ancestor { ActionController::API }
  requires_ancestor { ActionController::Cookies }

  private

  sig { returns(T.nilable(String)) }
  def session_cookie_id
    cookies.signed[:session_id]
  end

  sig { params(session_id: String, expires_at: ActiveSupport::TimeWithZone).void }
  def start_session_cookie(session_id, expires_at:)
    cookies.signed[:session_id] = {
      value: session_id, expires: expires_at, httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  sig { void }
  def end_session_cookie
    cookies.delete(:session_id)
  end
end
