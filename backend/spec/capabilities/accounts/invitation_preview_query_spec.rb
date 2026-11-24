# typed: false

require "rails_helper"

RSpec.describe Accounts::InvitationPreviewQuery do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:invitation_id) do
    Accounts::InviteAdministrator.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, school_id: innsmouth.id,
                                       email: "zadok.allen@example.com", name: "Zadok Allen", role: "assistant_admin").value
  end

  def preview(lock_version: 0)
    described_class.call(organization_id: eldritch.id, invitation_id:, lock_version:)
  end

  it "shows the invitation, and that the person has no account" do
    expect(preview.value.serialize).to eq(
      "email" => "zadok.allen@example.com", "name" => "Zadok Allen", "role" => "assistant_admin",
      "school_name" => "Innsmouth Heights Secondary School", "inviter_name" => "Marsha Deepwater", "has_account" => false
    )
  end

  it "shows that the person has an account" do
    create_identity(email: "zadok.allen@example.com", password: "a long password")

    expect(preview.value.has_account).to be(true)
  end

  it "does not show an invitation with another version (resent)" do
    expect(preview(lock_version: 1).errors.map(&:code)).to eq([ "invitation_link_invalid" ])
  end

  it "does not show a revoked invitation" do
    Accounts::RevokeInvitation.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, invitation_id:)
    lock_version = in_organization(eldritch) { Invitation.find(invitation_id).lock_version }

    expect(preview(lock_version:).errors.map(&:code)).to eq([ "invitation_link_invalid" ])
  end

  it "does not show an expired invitation" do
    travel Invitation::LIFETIME + 1.second

    expect(preview.category).to eq(:not_found)
  end
end
