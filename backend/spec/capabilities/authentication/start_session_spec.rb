# typed: false

require "rails_helper"

RSpec.describe Authentication::StartSession do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "marsha.deepwater@example.com", password: "a long password") }

  before { create_school_administrator(identity:, organization: eldritch, name: "Marsha Deepwater") }

  it "starts a session in the organization, for Session::LIFETIME" do
    freeze_time

    result = described_class.call(identity_id: identity.id, organization_id: eldritch.id,
                                  ip_address: "192.0.2.1", user_agent: "Firefox")

    session = Session.find(result.value.session_id)
    expect(session).to have_attributes(identity_id: identity.id, organization_id: eldritch.id,
                                       ip_address: "192.0.2.1", user_agent: "Firefox",
                                       expires_at: Session::LIFETIME.from_now.round(6))
    expect(result.value.expires_at).to eq(session.expires_at)
  end

  it "starts a session without an organization" do
    result = described_class.call(identity_id: identity.id)

    expect(Session.find(result.value.session_id).organization_id).to be_nil
  end

  it "does not start a session in an organization where the identity has no user" do
    result = described_class.call(identity_id: identity.id, organization_id: realms.id)

    expect(result.errors.map(&:code)).to eq([ "not_a_member" ])
    expect(Session.count).to eq(0)
  end
end
