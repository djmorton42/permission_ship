require "rails_helper"

# Login for school administrators. See "Identities and login" in architecture.md.
RSpec.describe "Session API", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let(:pines) { create_school(organization: eldritch, name: "The School Beyond the Pines") }
  let(:quest) { create_school(organization: realms, name: "Quest Preparatory Academy") }

  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }

  def log_in(email:, password:)
    api_post "/api/v1/session", { email:, password: }
  end

  def current_session
    get "/api/v1/session"
    response.parsed_body
  end

  def invalid_credentials
    { "errors" => [ { "field" => nil, "code" => "invalid_credentials", "message" => "Email or password is incorrect." } ] }
  end

  context "when the administrator has a user in one organization" do
    before do
      # Another administrator in the same board, at a school this person does not administer.
      colleague = create_identity(email: "barnabas.marsh@innsmouth.example", password: "another password")
      create_school_administrator(identity: colleague, organization: eldritch, name: "Barnabas Marsh", schools: [ pines ])
      quest # a school in another board
      create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen", schools: [ innsmouth ])
    end

    it "logs in and shows the administrator's organization and schools" do
      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")

      expect(response).to have_http_status(:no_content)
      expect(current_session).to eq(
        "status" => "signed_in",
        "user" => { "name" => "Zadok Allen" },
        "organization" => { "id" => eldritch.id, "name" => "Eldritch Shores Board of Education" },
        "administered_schools" => [ { "id" => innsmouth.id, "name" => "Innsmouth Heights Secondary School" } ]
      )
    end

    it "tells caches not to store the session" do
      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")

      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("signed_in")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "limits login attempts" do
      10.times { log_in(email: "zadok.allen@innsmouth.example", password: "shoggoth") }

      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "rate_limited" ])
      expect(Session.count).to eq(0)
    end

    it "accepts the email with other capitals and spaces" do
      log_in(email: "  Zadok.Allen@Innsmouth.Example ", password: "deep ones rising")

      expect(response).to have_http_status(:no_content)
      expect(current_session["status"]).to eq("signed_in")
    end

    it "rejects a wrong password" do
      log_in(email: "zadok.allen@innsmouth.example", password: "shoggoth")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq(invalid_credentials)
      expect(current_session).to eq(
        "errors" => [ { "field" => nil, "code" => "not_logged_in", "message" => "Log in to continue." } ]
      )
    end

    it "logs out" do
      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")

      api_delete "/api/v1/session"

      expect(response).to have_http_status(:no_content)
      get "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
    end

    it "ends the session on the server when the person logs out" do
      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")
      logged_in_cookie = cookies[:session_id]

      api_delete "/api/v1/session"
      cookies[:session_id] = logged_in_cookie
      get "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "rejects an unknown email with the same error as a wrong password" do
    log_in(email: "nobody@innsmouth.example", password: "deep ones rising")

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq(invalid_credentials)
  end

  it "rejects an identity that has no user in any organization" do
    identity

    log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["errors"].map { it["code"] }).to eq([ "no_organization" ])
  end

  it "requires login to show the session" do
    get "/api/v1/session"

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not accept a session cookie that the server did not sign" do
    create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen", schools: [ innsmouth ])
    session = Session.create!(identity:, organization: eldritch, expires_at: 1.hour.from_now)

    cookies[:session_id] = session.id
    get "/api/v1/session"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the administrator has users in two organizations" do
    before do
      create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen", schools: [ innsmouth ])
      create_school_administrator(identity:, organization: realms, name: "Sir Zadok of Quest", schools: [ quest ])
      log_in(email: "zadok.allen@innsmouth.example", password: "deep ones rising")
    end

    it "asks the person to pick an organization" do
      expect(response).to have_http_status(:no_content)
      expect(current_session).to eq(
        "status" => "organization_required",
        "organizations" => [
          { "id" => eldritch.id, "name" => "Eldritch Shores Board of Education" },
          { "id" => realms.id, "name" => "United Realms District School Board" }
        ]
      )
    end

    it "shows only the picked organization's data" do
      api_post "/api/v1/session/organization", { organization_id: realms.id }

      expect(response).to have_http_status(:no_content)
      expect(current_session).to eq(
        "status" => "signed_in",
        "user" => { "name" => "Sir Zadok of Quest" },
        "organization" => { "id" => realms.id, "name" => "United Realms District School Board" },
        "administered_schools" => [ { "id" => quest.id, "name" => "Quest Preparatory Academy" } ]
      )
    end

    it "does not let the person pick an organization where they have no user" do
      directorate = Organization.create!(name: "Central Directorate of Approved Learning")

      api_post "/api/v1/session/organization", { organization_id: directorate.id }

      expect(response).to have_http_status(:forbidden)
      expect(current_session["status"]).to eq("organization_required")
    end
  end

  it "requires login to pick an organization" do
    api_post "/api/v1/session/organization", { organization_id: eldritch.id }

    expect(response).to have_http_status(:unauthorized)
  end
end
