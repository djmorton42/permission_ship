# typed: false

require "rails_helper"

RSpec.describe Accounts::InviteAdministrator do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let(:pines) { create_school(organization: eldritch, name: "The School Beyond the Pines") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }

  def invite(email: "zadok.allen@example.com", name: "Zadok Allen", role: "assistant_admin", school: innsmouth, **inviter)
    inviter = { actor_user_id: marsha.user_id } if inviter.empty?
    perform_enqueued_jobs do
      described_class.call(organization_id: eldritch.id, school_id: school.id, email:, name:, role:, **inviter)
    end
  end

  def invitations = in_organization(eldritch) { Invitation.order(:created_at).to_a }

  it "invites a person by email, and records who did it" do
    freeze_time

    result = invite(email: " Zadok.Allen@Example.com ", name: "Zadok Allen", role: "assistant_admin")

    expect(result).to be_success
    invitation = invitations.sole
    expect(result.value).to eq(invitation.id)
    expect(invitation).to have_attributes(
      school_id: innsmouth.id, email: "zadok.allen@example.com", name: "Zadok Allen", role: "assistant_admin",
      invited_by_user_id: marsha.user_id, operator_reference: nil, expires_at: 7.days.from_now
    )
    expect(invitation).to be_open
    expect(audit_events(eldritch).map { it.slice(:actor_user_id, :action, :subject_id, :details) })
      .to eq([ { "actor_user_id" => marsha.user_id, "action" => "invitation.created", "subject_id" => invitation.id,
                 "details" => { "school_id" => [ nil, innsmouth.id ], "email" => [ nil, "zadok.allen@example.com" ],
                                "role" => [ nil, "assistant_admin" ] } } ])
  end

  it "emails a link that leads to the invitation" do
    invite(email: "zadok.allen@example.com", role: "admin")

    mail = sent_mail.sole
    expect(mail.to).to eq([ "zadok.allen@example.com" ])
    expect(mail.subject).to eq("You are invited to administer Innsmouth Heights Secondary School")
    expect(mail.text_part.body.decoded).to include("Marsha Deepwater invited you", "as an admin")
    payload = Accounts::InvitationToken.read(invitation_token(mail))
    expect(payload.serialize).to eq("organization_id" => eldritch.id, "invitation_id" => invitations.sole.id,
                                     "lock_version" => 0)
  end

  it "lets the operations team invite the first admin" do
    result = invite(role: "admin", operator_reference: "Ops: Avery Lin, ticket ONB-42")

    expect(result).to be_success
    expect(invitations.sole).to have_attributes(invited_by_user_id: nil, operator_reference: "Ops: Avery Lin, ticket ONB-42")
    expect(audit_events(eldritch).sole).to have_attributes(actor_user_id: nil, operator_reference: "Ops: Avery Lin, ticket ONB-42")
    expect(sent_mail.sole.text_part.body.decoded).to include("You are invited to administer")
  end

  it "does not let an assistant admin invite" do
    result = invite(actor_user_id: ida.user_id)

    expect(result.category).to eq(:forbidden)
    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(invitations).to be_empty
    expect(sent_mail).to be_empty
  end

  it "does not let an admin of another school invite" do
    result = invite(school: pines)

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(invitations).to be_empty
  end

  it "does not let a request without a user invite" do
    result = invite(actor_user_id: nil)

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(invitations).to be_empty
  end

  it "does not send a second invitation while one is open for the person and school" do
    invite(email: "zadok.allen@example.com")

    result = invite(email: "ZADOK.ALLEN@example.com")

    expect(result.category).to eq(:conflict)
    expect(result.errors.map(&:code)).to eq([ "invitation_open" ])
    expect(invitations.size).to eq(1)
    expect(sent_mail.size).to eq(1)
  end

  it "invites the person again after the open invitation was revoked" do
    invite(email: "zadok.allen@example.com")
    in_organization(eldritch) { invitations.sole.update!(revoked_at: Time.current) }

    expect(invite(email: "zadok.allen@example.com")).to be_success
    expect(invitations.size).to eq(2)
  end

  it "invites a person who is open for another school" do
    pines_admin = add_school_administrator(school: pines, name: "Silas Pine", role: "admin")
    invite(email: "zadok.allen@example.com")

    expect(invite(email: "zadok.allen@example.com", school: pines, actor_user_id: pines_admin.user_id)).to be_success
  end

  it "does not invite a person who already administers the school" do
    result = invite(email: "ida.fathom@example.com", role: "admin")

    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:code)).to eq([ "already_administrator" ])
    expect(invitations).to be_empty
  end

  it "rejects an invalid email, a missing name and an unknown role" do
    result = invite(email: "zadok", name: "", role: "principal")

    expect(result.errors.map(&:field)).to contain_exactly("email", "name", "role")
    expect(invitations).to be_empty
  end

  it "rejects both a user and an operator as the inviter" do
    result = invite(actor_user_id: marsha.user_id, operator_reference: "Ops: Avery Lin")

    expect(result.errors.map(&:code)).to eq([ "one_inviter_required" ])
    expect(invitations).to be_empty
  end
end
