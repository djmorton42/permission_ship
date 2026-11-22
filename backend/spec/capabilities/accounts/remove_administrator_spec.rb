# typed: false

require "rails_helper"

RSpec.describe Accounts::RemoveAdministrator do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }

  def remove(actor:, target:)
    described_class.call(organization_id: eldritch.id, actor_user_id: actor.user_id, school_administrator_id: target.id)
  end

  def administrator_names = in_organization(eldritch) { SchoolAdministrator.joins(:user).order("users.name").pluck("users.name") }

  it "lets an admin remove another administrator, and records who did it" do
    freeze_time

    result = remove(actor: marsha, target: ida)

    expect(result).to be_success
    expect(administrator_names).to eq([ "Marsha Deepwater" ])
    expect(audit_events(eldritch).map { it.slice(:actor_user_id, :action, :subject_type, :subject_id, :details, :created_at) })
      .to eq([ { "actor_user_id" => marsha.user_id, "action" => "school_administrator.removed",
                 "subject_type" => "SchoolAdministrator", "subject_id" => ida.id,
                 "details" => { "school_id" => [ innsmouth.id, nil ], "user_id" => [ ida.user_id, nil ],
                                "role" => [ "assistant_admin", nil ] },
                 "created_at" => Time.current } ])
  end

  it "lets an admin remove another admin" do
    silas = add_school_administrator(school: innsmouth, name: "Silas Pine", role: "admin")

    expect(remove(actor: marsha, target: silas)).to be_success
    expect(administrator_names).to eq([ "Ida Fathom", "Marsha Deepwater" ])
  end

  it "does not let an assistant admin remove an administrator" do
    obed = add_school_administrator(school: innsmouth, name: "Obed Marsh", role: "assistant_admin")

    result = remove(actor: ida, target: obed)

    expect(result.category).to eq(:forbidden)
    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(administrator_names).to eq([ "Ida Fathom", "Marsha Deepwater", "Obed Marsh" ])
    expect(audit_events(eldritch)).to be_empty
  end

  it "does not let an admin remove themselves" do
    result = remove(actor: marsha, target: marsha)

    expect(result.errors.map(&:code)).to eq([ "own_administration" ])
    expect(administrator_names).to eq([ "Ida Fathom", "Marsha Deepwater" ])
  end
end
