# typed: false

require "rails_helper"

RSpec.describe Accounts::RevokeInvitation do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }

  # The invitation email is enqueued, not sent yet.
  let(:invitation_id) do
    Accounts::InviteAdministrator.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, school_id: innsmouth.id,
                                       email: "zadok.allen@example.com", name: "Zadok Allen", role: "admin").value
  end

  def revoke(actor: marsha)
    described_class.call(organization_id: eldritch.id, actor_user_id: actor.user_id, invitation_id:)
  end

  def invitation = in_organization(eldritch) { Invitation.find(invitation_id) }

  it "closes the invitation, and records who did it" do
    freeze_time

    expect(revoke).to be_success

    expect(invitation.revoked_at).to eq(Time.current)
    expect(invitation).not_to be_open
    expect(audit_events(eldritch).last).to have_attributes(actor_user_id: marsha.user_id, action: "invitation.revoked",
                                                           subject_id: invitation_id)
  end

  it "stops an invitation email that was not sent yet" do
    revoke

    perform_enqueued_jobs

    expect(sent_mail).to be_empty
  end

  it "does not let an assistant admin revoke" do
    result = revoke(actor: ida)

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(invitation).to be_open
  end

  it "does not revoke an invitation that is closed" do
    revoke

    result = revoke

    expect(result.errors.map(&:code)).to eq([ "invitation_closed" ])
    expect(audit_events(eldritch).map(&:action)).to eq([ "invitation.created", "invitation.revoked" ])
  end
end
