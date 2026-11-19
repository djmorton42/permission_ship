# The login session ID, in a signed cookie that JavaScript cannot read.
# SameSite=Lax: browsers do not send the cookie with cross-site POST requests.
# The cookie expires when the session ends, so the browser deletes it.
module SessionCookie
  private

  def session_cookie_id
    cookies.signed[:session_id]
  end

  def start_session_cookie(session_id, expires_at:)
    cookies.signed[:session_id] = {
      value: session_id, expires: expires_at, httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def end_session_cookie
    cookies.delete(:session_id)
  end
end
