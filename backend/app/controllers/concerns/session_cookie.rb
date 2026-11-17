# The login session ID, in a signed cookie that JavaScript cannot read.
# SameSite=Lax: browsers do not send the cookie with cross-site POST requests.
module SessionCookie
  private

  def session_cookie_id
    cookies.signed[:session_id]
  end

  def start_session_cookie(session_id)
    cookies.signed.permanent[:session_id] = {
      value: session_id, httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def end_session_cookie
    cookies.delete(:session_id)
  end
end
