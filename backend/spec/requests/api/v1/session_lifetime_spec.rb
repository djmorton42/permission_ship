# typed: false

require "rails_helper"

# A session ends 9 hours after login, on the server and in the browser.
# It also ends after 30 minutes without a request, for example on a shared computer
# that the person walked away from. See "Session lifetime" in architecture.md.
RSpec.describe "Session lifetime", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:login_time) { Time.zone.parse("2026-11-19 07:30:00") }

  def log_in(at: login_time)
    travel_to(at) do
      api_post "/api/v1/session", { email: "zadok.allen@innsmouth.example", password: "deep ones rising" }
    end
    expect(response).to have_http_status(:no_content)
  end

  def session_status_at(time)
    travel_to(time) { get "/api/v1/session" }
    response.status
  end

  # A person who uses the app every 20 minutes, so the session is never idle for long.
  def stay_active(from:, to:)
    time = from + 20.minutes
    while time < to
      expect(session_status_at(time)).to eq(200), "the session ended early, at #{time}"
      time += 20.minutes
    end
  end

  context "when the person has one organization" do
    before { create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen") }

    it "keeps an active person logged in until 9 hours after login" do
      log_in
      stay_active(from: login_time, to: login_time + 8.hours + 59.minutes)

      expect(session_status_at(login_time + 8.hours + 59.minutes)).to eq(200)
      expect(response.parsed_body["status"]).to eq("signed_in")
    end

    it "ends the session 9 hours after login, even when the person is active" do
      log_in
      stay_active(from: login_time, to: login_time + 9.hours)

      expect(session_status_at(login_time + 9.hours)).to eq(401)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "not_logged_in" ])
    end

    it "ends the session at the server's end time, even before the cookie expires" do
      log_in
      # For example, a shorter lifetime, or a future "log out everywhere".
      Session.sole.update!(expires_at: login_time + 1.hour)
      stay_active(from: login_time, to: login_time + 59.minutes)

      expect(session_status_at(login_time + 59.minutes)).to eq(200)
      expect(session_status_at(login_time + 1.hour)).to eq(401)
    end

    it "rejects the cookie after the session ends, even if a client still sends it" do
      log_in
      copied_cookie = cookies[:session_id]

      travel_to(login_time + 9.hours) do
        # Without an expiry, the test client keeps this cookie. A copied cookie would do the same.
        cookies[:session_id] = copied_cookie
        get "/api/v1/session"
      end

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "not_logged_in" ])
    end

    it "tells the browser to delete the cookie when the session ends" do
      log_in

      set_cookie = response.headers["Set-Cookie"]
      expect(set_cookie).to include("session_id=")
      expect(set_cookie).to include("expires=Thu, 19 Nov 2026 16:30:00 GMT")
    end

    it "starts a new 9-hour session when the person logs in again" do
      log_in
      second_login = login_time + 10.hours
      log_in(at: second_login)
      stay_active(from: second_login, to: second_login + 8.hours + 59.minutes)

      expect(session_status_at(second_login + 8.hours + 59.minutes)).to eq(200)
    end
  end

  context "when the person stops using the app" do
    before { create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen") }

    it "keeps the session for 30 minutes without a request" do
      log_in

      expect(session_status_at(login_time + 29.minutes + 59.seconds)).to eq(200)
    end

    it "ends the session after 30 minutes without a request" do
      log_in

      expect(session_status_at(login_time + 30.minutes)).to eq(401)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "not_logged_in" ])
    end

    it "starts the 30 minutes again with each request" do
      log_in

      expect(session_status_at(login_time + 20.minutes)).to eq(200)
      expect(session_status_at(login_time + 49.minutes)).to eq(200)
      expect(session_status_at(login_time + 79.minutes)).to eq(401)
    end
  end

  it "does not let the person pick an organization after the session ends" do
    create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen")
    create_school_administrator(identity:, organization: realms, name: "Sir Zadok of Quest")
    log_in
    stay_active(from: login_time, to: login_time + 9.hours)

    travel_to(login_time + 9.hours) do
      api_post "/api/v1/session/organization", { organization_id: realms.id }
    end

    expect(response).to have_http_status(:unauthorized)
    expect(Session.sole.organization_id).to be_nil
  end
end
