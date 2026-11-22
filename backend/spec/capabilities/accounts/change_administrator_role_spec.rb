# typed: false

require "rails_helper"

RSpec.describe Accounts::ChangeAdministratorRole do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }
  let(:pines) { create_school(organization: eldritch, name: "The School Beyond the Pines") }
  let!(:marsha) { add_school_administrator(school: innsmouth, name: "Marsha Deepwater", role: "admin") }
  let!(:ida) { add_school_administrator(school: innsmouth, name: "Ida Fathom", role: "assistant_admin") }

  def change(actor:, target:, role:)
    described_class.call(organization_id: eldritch.id, actor_user_id: actor&.user_id,
                         school_administrator_id: target.id, role:)
  end

  def role_of(administrator) = in_organization(eldritch) { administrator.reload.role }

  it "lets an admin promote an assistant admin, and records who did it" do
    freeze_time

    result = change(actor: marsha, target: ida, role: "admin")

    expect(result).to be_success
    expect(role_of(ida)).to eq("admin")
    expect(audit_events(eldritch).map { it.slice(:actor_user_id, :action, :subject_type, :subject_id, :details, :created_at) })
      .to eq([ { "actor_user_id" => marsha.user_id, "action" => "school_administrator.role_changed",
                 "subject_type" => "SchoolAdministrator", "subject_id" => ida.id,
                 "details" => { "role" => [ "assistant_admin", "admin" ] }, "created_at" => Time.current } ])
  end

  it "lets an admin demote another admin" do
    silas = add_school_administrator(school: innsmouth, name: "Silas Pine", role: "admin")

    result = change(actor: marsha, target: silas, role: "assistant_admin")

    expect(result).to be_success
    expect(role_of(silas)).to eq("assistant_admin")
    expect(audit_events(eldritch).sole.details).to eq("role" => [ "admin", "assistant_admin" ])
  end

  it "does not let an assistant admin change a role" do
    obed = add_school_administrator(school: innsmouth, name: "Obed Marsh", role: "assistant_admin")

    result = change(actor: ida, target: obed, role: "admin")

    expect(result.category).to eq(:forbidden)
    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(role_of(obed)).to eq("assistant_admin")
    expect(audit_events(eldritch)).to be_empty
  end

  it "does not let an admin of another school change a role" do
    pines_admin = add_school_administrator(school: pines, name: "Silas Pine", role: "admin")

    result = change(actor: pines_admin, target: ida, role: "admin")

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(role_of(ida)).to eq("assistant_admin")
  end

  it "does not let a request without a user change a role" do
    result = change(actor: nil, target: ida, role: "admin")

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(role_of(ida)).to eq("assistant_admin")
  end

  it "does not let an admin change their own role" do
    add_school_administrator(school: innsmouth, name: "Silas Pine", role: "admin")

    result = change(actor: marsha, target: marsha, role: "assistant_admin")

    expect(result.errors.map(&:code)).to eq([ "own_administration" ])
    expect(role_of(marsha)).to eq("admin")
  end

  it "does not let a demoted admin demote the admin who demoted them" do
    silas = add_school_administrator(school: innsmouth, name: "Silas Pine", role: "admin")
    change(actor: marsha, target: silas, role: "assistant_admin")

    result = change(actor: silas, target: marsha, role: "assistant_admin")

    expect(result.errors.map(&:code)).to eq([ "admin_required" ])
    expect(role_of(marsha)).to eq("admin")
  end

  it "records nothing when the role does not change" do
    result = change(actor: marsha, target: ida, role: "assistant_admin")

    expect(result).to be_success
    expect(audit_events(eldritch)).to be_empty
  end

  it "rejects a role that does not exist" do
    result = change(actor: marsha, target: ida, role: "principal")

    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:field)).to eq([ "role" ])
    expect(role_of(ida)).to eq("assistant_admin")
  end

  it "does not find an administrator in another organization" do
    realms = Organization.create!(name: "United Realms District School Board")
    quest = create_school(organization: realms, name: "Quest Preparatory Academy")
    tobias = add_school_administrator(school: quest, name: "Tobias Emberwing", role: "assistant_admin")

    result = change(actor: marsha, target: tobias, role: "admin")

    expect(result.category).to eq(:not_found)
    expect(in_organization(realms) { tobias.reload.role }).to eq("assistant_admin")
  end
end
