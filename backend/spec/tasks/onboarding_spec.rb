# typed: false

require "rails_helper"
require "rake"

RSpec.describe "onboarding:invite_school_admin" do
  let(:eldritch) { Organization.create!(name: "Eldritch Shores Board of Education") }
  let(:innsmouth) { create_school(organization: eldritch, name: "Innsmouth Heights Secondary School") }

  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("onboarding:invite_school_admin") }

  def run_task(env)
    task = Rake::Task["onboarding:invite_school_admin"]
    task.reenable
    stub_const("ENV", ENV.to_h.merge(env))
    expect { task.invoke }.to output(/Invited/).to_stdout
  end

  let(:env) do
    { "ORGANIZATION_ID" => eldritch.id, "SCHOOL_ID" => innsmouth.id, "EMAIL" => "marsha.deepwater@example.com",
      "NAME" => "Marsha Deepwater", "OPERATOR" => "Ops: Avery Lin, ticket ONB-42" }
  end

  it "invites a school's first admin as the operator" do
    perform_enqueued_jobs { run_task(env) }

    invitation = in_organization(eldritch) { Invitation.sole }
    expect(invitation).to have_attributes(email: "marsha.deepwater@example.com", role: "admin",
                                          operator_reference: "Ops: Avery Lin, ticket ONB-42", invited_by_user_id: nil)
    expect(sent_mail.sole.to).to eq([ "marsha.deepwater@example.com" ])
  end

  it "fails and invites nobody without an operator" do
    expect { run_task(env.except("OPERATOR")) }.to raise_error(KeyError, /OPERATOR/)
    expect(in_organization(eldritch) { Invitation.count }).to eq(0)
  end

  it "fails when the command refuses the invitation" do
    run_task(env)

    expect { run_task(env) }.to raise_error(RuntimeError, /invitation_open/)
  end
end
