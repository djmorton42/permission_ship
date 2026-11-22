# typed: false

require "rails_helper"

RSpec.describe Accounts::ActorQuery do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "asenath.waite@example.com", password: "a long password") }

  it "returns the identity's user in the organization" do
    eldritch_user = create_school_administrator(identity:, organization: eldritch, name: "Asenath Waite")
    create_school_administrator(identity:, organization: realms, name: "Lady Asenath")

    expect(described_class.call(organization_id: eldritch.id, identity_id: identity.id).value).to eq(eldritch_user.id)
  end

  it "returns no user from another organization" do
    create_school_administrator(identity:, organization: realms, name: "Lady Asenath")

    expect(described_class.call(organization_id: eldritch.id, identity_id: identity.id).value).to be_nil
  end
end
