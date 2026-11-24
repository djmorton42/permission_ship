# typed: false

require "rails_helper"

RSpec.describe Accounts::AcceptInvitation do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:realms) { Organization.create!(name: "United Realms District School Board") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let(:arkham) { create_school(organization: eldritch, name: "Arkham Valley Elementary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }

  def invite(school: innsmouth, role: "assistant_admin")
    Accounts::InviteAdministrator.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, school_id: school.id,
                                       email: "zadok.allen@example.com", name: "Zadok Allen", role:).value
  end

  def accept(invitation_id, password: "a long password", lock_version: 0)
    described_class.call(organization_id: eldritch.id, invitation_id:, lock_version:, password:)
  end

  def invitation(id) = in_organization(eldritch) { Invitation.find(id) }

  def zadok = in_organization(eldritch) { User.joins(:identity).find_by!(identities: { email: "zadok.allen@example.com" }) }

  it "makes a new person an administrator in the invited role, with the password they set" do
    invitation_id = invite

    result = accept(invitation_id)

    expect(result).to be_success
    identity = Identity.find_by!(email: "zadok.allen@example.com")
    expect(result.value).to eq(identity.id)
    expect(identity.authenticate("a long password")).to be_truthy
    expect(zadok.name).to eq("Zadok Allen")
    expect(in_organization(eldritch) { SchoolAdministrator.find_by!(user: zadok) })
      .to have_attributes(school_id: innsmouth.id, role: "assistant_admin")
    expect(invitation(invitation_id).accepted_at).to be_present
  end

  it "records who accepted, as an audit event" do
    invitation_id = invite

    accept(invitation_id)

    administrator = in_organization(eldritch) { SchoolAdministrator.find_by!(user: zadok) }
    expect(audit_events(eldritch).last).to have_attributes(
      actor_user_id: zadok.id, action: "invitation.accepted", subject_type: "Invitation", subject_id: invitation_id,
      details: { "school_administrator_id" => [ nil, administrator.id ], "role" => [ nil, "assistant_admin" ] }
    )
  end

  it "lets a person with an account accept with their password, and keeps their user" do
    identity = create_identity(email: "zadok.allen@example.com", password: "my own password")
    user = create_school_administrator(identity:, organization: eldritch, name: "Zadok Allen", schools: [ arkham ])
    invitation_id = invite

    result = accept(invitation_id, password: "my own password")

    expect(result.value).to eq(identity.id)
    expect(in_organization(eldritch) { SchoolAdministrator.where(user:).pluck(:school_id) })
      .to contain_exactly(arkham.id, innsmouth.id)
  end

  it "adds a user in the organization for a person who has an account in another organization" do
    identity = create_identity(email: "zadok.allen@example.com", password: "my own password")
    create_school_administrator(identity:, organization: realms, name: "Zadok Allen")

    accept(invite, password: "my own password")

    expect(zadok.identity_id).to eq(identity.id)
  end

  it "does not accept a wrong password for an existing account, and leaves the invitation open" do
    create_identity(email: "zadok.allen@example.com", password: "my own password")
    invitation_id = invite

    result = accept(invitation_id, password: "a guess")

    expect(result.errors.map(&:code)).to eq([ "incorrect_password" ])
    expect(invitation(invitation_id)).to be_open
    expect(in_organization(eldritch) { User.count }).to eq(1)
  end

  it "accepts an invitation only once" do
    invitation_id = invite
    accept(invitation_id)

    result = accept(invitation_id, lock_version: invitation(invitation_id).lock_version)

    expect(result.errors.map(&:code)).to eq([ "invitation_link_invalid" ])
  end

  it "does not accept an old link after a resend" do
    invitation_id = invite
    Accounts::ResendInvitation.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, invitation_id:, lock_version: 0)

    result = accept(invitation_id, lock_version: 0)

    expect(result.category).to eq(:not_found)
    expect(Identity.where(email: "zadok.allen@example.com")).not_to exist
  end

  it "does not accept an expired invitation" do
    invitation_id = invite
    travel Invitation::LIFETIME + 1.second

    expect(accept(invitation_id).category).to eq(:not_found)
  end

  it "does not find an invitation in another organization" do
    invitation_id = invite

    result = described_class.call(organization_id: realms.id, invitation_id:, lock_version: 0, password: "a long password")

    expect(result.category).to eq(:not_found)
  end
end
