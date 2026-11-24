# typed: false

require "rails_helper"

# A person opens the link in an invitation email, then accepts with a password.
RSpec.describe "Invitation acceptances", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:token) do
    perform_enqueued_jobs do
      Accounts::InviteAdministrator.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, school_id: innsmouth.id,
                                         email: "zadok.allen@example.com", name: "Zadok Allen", role: "admin")
    end
    invitation_token(sent_mail.sole)
  end

  def error_codes = response.parsed_body["errors"].map { it["code"] }

  it "shows the invitation for the token in the link" do
    api_post "/api/v1/invitation_acceptances/preview", { token: }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "email" => "zadok.allen@example.com", "name" => "Zadok Allen", "role" => "admin",
      "school_name" => "Innsmouth Heights Secondary School", "inviter_name" => "Marsha Deepwater", "has_account" => false
    )
  end

  it "does not show an invitation for a changed token" do
    api_post "/api/v1/invitation_acceptances/preview", { token: "#{token}x" }

    expect(response).to have_http_status(:not_found)
    expect(error_codes).to eq([ "invitation_link_invalid" ])
  end

  it "accepts the invitation, and logs the person in to the organization" do
    api_post "/api/v1/invitation_acceptances", { token:, password: "a long password" }

    expect(response).to have_http_status(:no_content)
    get "/api/v1/session"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("user", "name")).to eq("Zadok Allen")
  end

  it "ends the session that the browser had before" do
    api_post "/api/v1/session", { email: "marsha.deepwater@example.com", password: "a long password" }
    old_session_id = Session.sole.id

    api_post "/api/v1/invitation_acceptances", { token:, password: "a long password" }

    expect(Session.where(id: old_session_id)).not_to exist
    expect(Session.count).to eq(1)
  end

  it "does not log in when the password is wrong for an existing account" do
    create_identity(email: "zadok.allen@example.com", password: "my own password")

    api_post "/api/v1/invitation_acceptances", { token:, password: "a guess" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(error_codes).to eq([ "incorrect_password" ])
    expect(Session.count).to eq(0)
  end

  it "does not accept a changed token" do
    api_post "/api/v1/invitation_acceptances", { token: "#{token}x", password: "a long password" }

    expect(response).to have_http_status(:not_found)
    expect(Identity.where(email: "zadok.allen@example.com")).not_to exist
  end

  it "limits acceptance attempts" do
    create_identity(email: "zadok.allen@example.com", password: "my own password")

    11.times { api_post "/api/v1/invitation_acceptances", { token:, password: "a guess" } }

    expect(response).to have_http_status(:too_many_requests)
  end
end
