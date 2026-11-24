# typed: false

require "rails_helper"

RSpec.describe Accounts::ResendInvitation do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }
  let(:invitation_id) do
    perform_enqueued_jobs do
      Accounts::InviteAdministrator.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, school_id: innsmouth.id,
                                         email: "zadok.allen@example.com", name: "Zadok Allen", role: "admin").value
    end
  end

  def resend(actor: marsha, lock_version: 0)
    perform_enqueued_jobs do
      described_class.call(organization_id: eldritch.id, actor_user_id: actor.user_id, invitation_id:, lock_version:)
    end
  end

  def invitation = in_organization(eldritch) { Invitation.find(invitation_id) }

  it "sends a new link that works for another 7 days, and stops the old link" do
    invitation_id
    first_token = Accounts::InvitationToken.read(invitation_token(sent_mail.sole))
    travel 8.days

    result = resend(lock_version: 0)

    expect(result).to be_success
    expect(invitation.expires_at).to eq(7.days.from_now.round(6))
    new_token = Accounts::InvitationToken.read(invitation_token(sent_mail.last))
    expect(new_token.lock_version).to eq(invitation.lock_version)
    expect(first_token.lock_version).not_to eq(invitation.lock_version)
    expect(audit_events(eldritch).last).to have_attributes(actor_user_id: marsha.user_id, action: "invitation.resent",
                                                           subject_id: invitation_id)
  end

  it "does not send again for a repeated request" do
    invitation_id
    resend(lock_version: 0)

    result = resend(lock_version: 0)

    expect(result.category).to eq(:conflict)
    expect(result.errors.map(&:code)).to eq([ "invitation_changed" ])
    expect(sent_mail.size).to eq(2)
  end

  it "does not let an assistant admin resend" do
    invitation_id

    result = resend(actor: ida)

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(sent_mail.size).to eq(1)
  end

  it "does not resend a revoked invitation" do
    Accounts::RevokeInvitation.call(organization_id: eldritch.id, actor_user_id: marsha.user_id, invitation_id:)

    result = resend(lock_version: invitation.lock_version)

    expect(result.errors.map(&:code)).to eq([ "invitation_closed" ])
    expect(sent_mail.size).to eq(1)
  end

  it "does not find an unknown invitation" do
    result = described_class.call(organization_id: eldritch.id, actor_user_id: marsha.user_id,
                                  invitation_id: SecureRandom.uuid, lock_version: 0)

    expect(result.category).to eq(:not_found)
  end
end
