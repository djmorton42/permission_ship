# typed: false

require "rails_helper"

# Admins invite people to administer their school.
RSpec.describe "Invitations", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }

  # add_school_administrator makes the email from the name.
  def log_in_as(email)
    api_post "/api/v1/session", { email:, password: "a long password" }
    api_post "/api/v1/session/organization", { organization_id: eldritch.id }
    expect(response).to have_http_status(:no_content)
  end

  def invite
    perform_enqueued_jobs do
      api_post "/api/v1/schools/#{innsmouth.id}/invitations",
               { email: "zadok.allen@example.com", name: "Zadok Allen", role: "assistant_admin" }
    end
  end

  def invitation = in_organization(eldritch) { Invitation.sole }

  def error_codes = response.parsed_body["errors"].map { it["code"] }

  it "lets an admin invite a person, as the logged-in user" do
    log_in_as("marsha.deepwater@example.com")

    invite

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq("id" => invitation.id)
    expect(invitation.invited_by_user_id).to eq(marsha.user_id)
    expect(sent_mail.sole.to).to eq([ "zadok.allen@example.com" ])
  end

  it "does not let an assistant admin invite" do
    log_in_as("ida.fathom@example.com")

    invite

    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "admin_required" ])
    expect(sent_mail).to be_empty
  end

  it "ignores an operator reference in the request" do
    log_in_as("ida.fathom@example.com")

    api_post "/api/v1/schools/#{innsmouth.id}/invitations",
             { email: "zadok.allen@example.com", name: "Zadok Allen", role: "admin", operator_reference: "Ops" }

    expect(response).to have_http_status(:forbidden)
  end

  it "returns a conflict for a second invitation to the same person" do
    log_in_as("marsha.deepwater@example.com")
    invite

    invite

    expect(response).to have_http_status(:conflict)
    expect(error_codes).to eq([ "invitation_open" ])
  end
end
