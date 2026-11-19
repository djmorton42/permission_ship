require "rails_helper"

# A session ends 12 hours after login, on the server and in the browser.
# Reason: school computers are shared. See "Session lifetime" in architecture.md.
RSpec.describe "Session lifetime", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:login_time) { Time.zone.parse("2026-11-19 07:30:00") }

  def log_in
    travel_to(login_time) do
      api_post "/api/v1/session", { email: "zadok.allen@innsmouth.example", password: "deep ones rising" }
    end
    expect(response).to have_http_status(:no_content)
  end

  def session_status_at(time)
    travel_to(time) { get "/api/v1/session" }
    response.status
  end

  context "when the person has one organization" do
    before { create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen") }

    it "keeps the person logged in until 12 hours after login" do
      log_in

      expect(session_status_at(login_time + 11.hours + 59.minutes)).to eq(200)
      expect(response.parsed_body["status"]).to eq("signed_in")
    end

    it "ends the session 12 hours after login" do
      log_in

      expect(session_status_at(login_time + 12.hours)).to eq(401)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "not_logged_in" ])
    end

    it "rejects the cookie after the session ends, even if a client still sends it" do
      log_in
      copied_cookie = cookies[:session_id]

      travel_to(login_time + 12.hours) do
        # Without an expiry, the test client keeps this cookie. A copied cookie would do the same.
        cookies[:session_id] = copied_cookie
        get "/api/v1/session"
      end

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "not_logged_in" ])
    end

    it "ends the session at the server's end time, even before the cookie expires" do
      log_in
      # For example, a shorter lifetime, or a future "log out everywhere".
      Session.sole.update!(expires_at: login_time + 1.hour)

      expect(session_status_at(login_time + 59.minutes)).to eq(200)
      expect(session_status_at(login_time + 1.hour)).to eq(401)
    end

    it "tells the browser to delete the cookie when the session ends" do
      log_in

      set_cookie = response.headers["Set-Cookie"]
      expect(set_cookie).to include("session_id=")
      expect(set_cookie).to include("expires=Thu, 19 Nov 2026 19:30:00 GMT")
    end

    it "starts a new 12-hour session when the person logs in again" do
      log_in
      second_login = login_time + 13.hours
      travel_to(second_login) do
        api_post "/api/v1/session", { email: "zadok.allen@innsmouth.example", password: "deep ones rising" }
      end

      expect(session_status_at(second_login + 11.hours)).to eq(200)
    end
  end

  it "does not let the person pick an organization after the session ends" do
    create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen")
    create_school_administrator(identity:, organization: realms, name: "Sir Zadok of Quest")
    log_in

    travel_to(login_time + 12.hours) do
      api_post "/api/v1/session/organization", { organization_id: realms.id }
    end

    expect(response).to have_http_status(:unauthorized)
    expect(Session.sole.organization_id).to be_nil
  end
end
