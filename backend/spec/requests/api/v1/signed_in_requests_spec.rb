# typed: false

require "rails_helper"

# Every API endpoint needs a signed-in session in an organization, unless its controller opts out.
# The organization comes from the session, never from the request.
# See "Signed-in requests" in architecture.md.
RSpec.describe "Signed-in requests", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }

  # A controller that declares no session rules, so it gets the defaults.
  # It passes the request's organization_id on, as a careless controller could.
  before do
    stub_const("SpecCurrentUserController", Class.new(Api::V1::BaseController) do
      def show
        render_result(Accounts::CurrentUserQuery.call(
          organization_inputs(params.permit(:organization_id).to_h.merge(identity_id: current_session.identity_id))
        ))
      end
    end)
  end

  around do |example|
    with_routing do |routes|
      # with_routing replaces all routes. The login routes are copied from config/routes.rb.
      routes.draw do
        get "/spec/current_user" => "spec_current_user#show"
        namespace :api, defaults: { format: :json } do
          namespace :v1 do
            resource :session, only: %i[create destroy] do
              resource :organization, only: :create, controller: "session_organizations"
            end
          end
        end
      end
      example.run
    end
  end

  def log_in
    api_post "/api/v1/session", { email: "zadok.allen@innsmouth.example", password: "deep ones rising" }
    expect(response).to have_http_status(:no_content)
  end

  def error_codes
    response.parsed_body["errors"].map { it["code"] }
  end

  it "rejects a request without a session" do
    get "/spec/current_user"

    expect(response).to have_http_status(:unauthorized)
    expect(error_codes).to eq([ "not_logged_in" ])
  end

  it "rejects a request after logout, with the old cookie" do
    create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen")
    log_in
    old_cookie = cookies[:session_id]
    api_delete "/api/v1/session"

    cookies[:session_id] = old_cookie
    get "/spec/current_user"

    expect(response).to have_http_status(:unauthorized)
    expect(error_codes).to eq([ "not_logged_in" ])
  end

  context "when the person is in two organizations" do
    before do
      create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen")
      create_school_administrator(identity:, organization: realms, name: "Sir Zadok of Quest")
      log_in
    end

    it "asks for an organization before the person picks one" do
      get "/spec/current_user"

      expect(response).to have_http_status(:forbidden)
      expect(error_codes).to eq([ "organization_required" ])
    end

    it "uses the organization the person picked" do
      api_post "/api/v1/session/organization", { organization_id: eldritch.id }

      get "/spec/current_user"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]).to eq("name" => "Zadok Allen")
      expect(response.parsed_body["organization"]["id"]).to eq(eldritch.id)
    end

    it "ignores an organization ID in the request" do
      api_post "/api/v1/session/organization", { organization_id: eldritch.id }

      get "/spec/current_user", params: { organization_id: realms.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]).to eq("name" => "Zadok Allen")
      expect(response.parsed_body["organization"]["id"]).to eq(eldritch.id)
    end
  end
end
