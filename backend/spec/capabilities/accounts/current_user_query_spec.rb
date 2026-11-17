require "rails_helper"

RSpec.describe Accounts::CurrentUserQuery do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:identity) { create_identity(email: "asenath.waite@example.com", password: "a long password") }

  it "returns no data from another organization" do
    quest = create_school(organization: realms, name: "Quest Preparatory Academy")
    create_school_administrator(identity:, organization: realms, name: "Asenath Waite", schools: [ quest ])

    result = described_class.call(organization_id: eldritch.id, identity_id: identity.id)

    expect(result.category).to eq(:not_found)
  end

  it "returns the user and schools in the given organization when the identity is in two" do
    innsmouth = create_school(organization: eldritch, name: "Innsmouth Heights Secondary School")
    quest = create_school(organization: realms, name: "Quest Preparatory Academy")
    create_school_administrator(identity:, organization: eldritch, name: "Asenath Waite", schools: [ innsmouth ])
    create_school_administrator(identity:, organization: realms, name: "Lady Asenath", schools: [ quest ])

    user = described_class.call(organization_id: eldritch.id, identity_id: identity.id).value

    expect(user.name).to eq("Asenath Waite")
    expect(user.administered_schools.map(&:name)).to eq([ "Innsmouth Heights Secondary School" ])
  end
end
