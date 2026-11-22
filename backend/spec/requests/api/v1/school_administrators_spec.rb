# typed: false

require "rails_helper"

# Admins change the roles of a school's administrators and remove them.
RSpec.describe "School administrators", type: :request do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }
  let!(:silas) { add_school_administrator(school: innsmouth, name: "Silas Pine", role: "admin") }

  # add_school_administrator makes the email from the name.
  def log_in_as(email)
    api_post "/api/v1/session", { email:, password: "a long password" }
    api_post "/api/v1/session/organization", { organization_id: eldritch.id }
    expect(response).to have_http_status(:no_content)
  end

  def role_of(administrator) = in_organization(eldritch) { administrator.reload.role }

  def error_codes = response.parsed_body["errors"].map { it["code"] }

  it "lets an admin demote another admin, as the logged-in user" do
    log_in_as("marsha.deepwater@example.com")

    api_patch "/api/v1/school_administrators/#{silas.id}", { role: "assistant_admin" }

    expect(response).to have_http_status(:no_content)
    expect(role_of(silas)).to eq("assistant_admin")
    expect(audit_events(eldritch).sole.actor_user_id).to eq(marsha.user_id)
  end

  it "does not let an assistant admin promote themselves" do
    log_in_as("ida.fathom@example.com")

    api_patch "/api/v1/school_administrators/#{ida.id}", { role: "admin" }

    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "admin_required" ])
    expect(role_of(ida)).to eq("assistant_admin")
  end

  it "rejects a role that does not exist" do
    log_in_as("marsha.deepwater@example.com")

    api_patch "/api/v1/school_administrators/#{ida.id}", { role: "principal" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(role_of(ida)).to eq("assistant_admin")
  end

  it "lets an admin remove an administrator" do
    log_in_as("marsha.deepwater@example.com")

    api_delete "/api/v1/school_administrators/#{ida.id}"

    expect(response).to have_http_status(:no_content)
    expect(in_organization(eldritch) { SchoolAdministrator.exists?(ida.id) }).to be(false)
  end

  it "does not let an admin remove themselves" do
    log_in_as("marsha.deepwater@example.com")

    api_delete "/api/v1/school_administrators/#{marsha.id}"

    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "own_administration" ])
  end

  it "returns not found for an unknown administrator" do
    log_in_as("marsha.deepwater@example.com")

    api_delete "/api/v1/school_administrators/#{SecureRandom.uuid}"

    expect(response).to have_http_status(:not_found)
  end
end
