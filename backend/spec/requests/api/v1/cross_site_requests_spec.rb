require "rails_helper"

# Cookie-authenticated writes accept only JSON from an allowed origin.
# SameSite=Lax does not stop a cross-site form from setting a new session cookie (login CSRF).
# See "Sessions and CSRF" in architecture.md.
RSpec.describe "Cross-site request protection", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }
  let(:credentials) { { email: "zadok.allen@innsmouth.example", password: "deep ones rising" } }

  before do
    create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen")
  end

  def error_codes
    response.parsed_body["errors"].map { it["code"] }
  end

  describe "login" do
    it "rejects a form post from another site, and starts no session" do
      post "/api/v1/session", params: credentials, headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      expect(error_codes).to eq([ "origin_not_allowed" ])
      expect(response.headers["Set-Cookie"]).to be_nil
      expect(Session.count).to eq(0)
    end

    it "rejects JSON from another site" do
      post "/api/v1/session", params: credentials, as: :json, headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      expect(Session.count).to eq(0)
    end

    it "rejects a request without an Origin header" do
      post "/api/v1/session", params: credentials, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Session.count).to eq(0)
    end

    it "rejects a form post from the app's own origin" do
      post "/api/v1/session", params: credentials, headers: { "Origin" => ApiRequestHelpers::OWN_ORIGIN }

      expect(response).to have_http_status(:unsupported_media_type)
      expect(error_codes).to eq([ "json_required" ])
      expect(response.headers["Set-Cookie"]).to be_nil
      expect(Session.count).to eq(0)
    end

    it "accepts JSON from the app's own origin" do
      api_post "/api/v1/session", credentials

      expect(response).to have_http_status(:no_content)
      expect(response.headers["Set-Cookie"]).to include("session_id=")
      expect(Session.count).to eq(1)
    end

    it "accepts JSON from an origin in the allow-list" do
      # The Vite dev server proxies the API, so the browser's origin is the frontend's.
      post "/api/v1/session", params: credentials, as: :json, headers: { "Origin" => "http://localhost:5173" }

      expect(response).to have_http_status(:no_content)
      expect(Session.count).to eq(1)
    end
  end

  describe "after login" do
    before { api_post "/api/v1/session", credentials }

    it "does not log out for another site" do
      delete "/api/v1/session", headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      expect(Session.count).to eq(1)
    end

    it "does not pick an organization for another site" do
      create_school_administrator(identity:, organization: realms, name: "Sir Zadok of Quest")
      Session.update_all(organization_id: nil)

      post "/api/v1/session/organization", params: { organization_id: realms.id }, as: :json,
                                           headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      expect(Session.sole.organization_id).to be_nil
    end

    it "still reads the session with GET, which needs no Origin" do
      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
    end
  end
end
