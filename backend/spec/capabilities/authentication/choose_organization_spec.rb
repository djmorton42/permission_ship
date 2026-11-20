# typed: false

require "rails_helper"

RSpec.describe Authentication::ChooseOrganization do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:identity) { create_identity(email: "zadok.allen@innsmouth.example", password: "deep ones rising") }

  before { create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen") }

  it "puts an active session in the organization" do
    session = Session.create!(identity:, expires_at: 1.hour.from_now, last_active_at: 29.minutes.ago)

    result = described_class.call(session_id: session.id, organization_id: eldritch.id)

    expect(result).to be_success
    expect(session.reload.organization_id).to eq(eldritch.id)
  end

  it "does not change a session that has ended" do
    session = Session.create!(identity:, expires_at: 1.second.ago, last_active_at: 1.minute.ago)

    result = described_class.call(session_id: session.id, organization_id: eldritch.id)

    expect(result.errors.map(&:code)).to eq([ "not_logged_in" ])
    expect(session.reload.organization_id).to be_nil
  end

  it "does not change a session that was idle for 30 minutes" do
    session = Session.create!(identity:, expires_at: 1.hour.from_now, last_active_at: 30.minutes.ago)

    result = described_class.call(session_id: session.id, organization_id: eldritch.id)

    expect(result.errors.map(&:code)).to eq([ "not_logged_in" ])
    expect(session.reload.organization_id).to be_nil
  end
end
