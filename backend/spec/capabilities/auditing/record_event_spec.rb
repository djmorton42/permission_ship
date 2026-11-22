# typed: false

require "rails_helper"

RSpec.describe Auditing::RecordEvent do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let(:marsha) do
    create_school_administrator(identity: create_identity(email: "marsha@eldritch-shores.example", password: "a long password"),
                                organization: eldritch, name: "Marsha Deepwater")
  end

  def events = in_organization(eldritch) { AuditEvent.all.to_a }

  it "records who changed what, and when" do
    freeze_time

    result = described_class.call(
      organization_id: eldritch.id, actor_user_id: marsha.id,
      action: "school_administrator.role_changed", subject_type: "SchoolAdministrator", subject_id: innsmouth.id,
      details: { "role" => [ "assistant_admin", "admin" ] }
    )

    expect(result).to be_success
    event = events.sole
    expect(event).to have_attributes(
      actor_user_id: marsha.id, operator_reference: nil,
      action: "school_administrator.role_changed", subject_type: "SchoolAdministrator", subject_id: innsmouth.id,
      details: { "role" => [ "assistant_admin", "admin" ] }, created_at: Time.current
    )
  end

  it "records a change by the operations team with the operator's reference" do
    result = described_class.call(
      organization_id: eldritch.id, operator_reference: "Ops: Avery Lin, ticket ONB-42",
      action: "school.onboarded", subject_type: "School", subject_id: innsmouth.id
    )

    expect(result).to be_success
    expect(events.sole).to have_attributes(actor_user_id: nil, operator_reference: "Ops: Avery Lin, ticket ONB-42",
                                           details: {})
  end

  it "rejects an event without an actor" do
    result = described_class.call(
      organization_id: eldritch.id, action: "school.onboarded", subject_type: "School", subject_id: innsmouth.id
    )

    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:to_h)).to eq([ { field: nil, code: "one_actor_required",
                                                message: "Give a user or an operator as the actor, not both." } ])
    expect(events).to be_empty
  end

  it "rejects an event with both a user and an operator as the actor" do
    result = described_class.call(
      organization_id: eldritch.id, actor_user_id: marsha.id, operator_reference: "Ops: Avery Lin",
      action: "school.onboarded", subject_type: "School", subject_id: innsmouth.id
    )

    expect(result.errors.map(&:code)).to eq([ "one_actor_required" ])
    expect(events).to be_empty
  end

  it "rejects an event without an action or a subject" do
    result = described_class.call(organization_id: eldritch.id, actor_user_id: marsha.id)

    expect(result.errors.map(&:field)).to contain_exactly("action", "subject_type", "subject_id")
    expect(events).to be_empty
  end

  # Specs run as the app role (config/database.yml, primary).
  it "does not let the app change or delete an event" do
    described_class.call(organization_id: eldritch.id, actor_user_id: marsha.id,
                         action: "school.onboarded", subject_type: "School", subject_id: innsmouth.id)
    event = events.sole

    expect {
      in_organization(eldritch) do
        ApplicationRecord.transaction(requires_new: true) { AuditEvent.where(id: event.id).update_all(action: "nothing") }
      end
    }.to raise_error(ActiveRecord::StatementInvalid, /permission denied/)
    expect {
      in_organization(eldritch) do
        ApplicationRecord.transaction(requires_new: true) { AuditEvent.where(id: event.id).delete_all }
      end
    }.to raise_error(ActiveRecord::StatementInvalid, /permission denied/)
  end
end
