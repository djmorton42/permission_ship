# typed: false

require "rails_helper"

RSpec.describe Accounts::AdministratorPolicy do
  # user_id is a UUID column, so each person needs a real UUID.
  let(:user_ids) { Hash.new { |ids, name| ids[name] = SecureRandom.uuid } }

  def administrator(name, role) = SchoolAdministrator.new(user_id: user_ids[name], role:)

  let(:admin) { administrator("marsha", "admin") }

  def codes(failure) = failure&.errors&.map(&:code)

  it "lets an admin change another admin or an assistant admin" do
    expect(described_class.check_change(actor: admin, target: administrator("ida", "admin"))).to be_nil
    expect(described_class.check_change(actor: admin, target: administrator("silas", "assistant_admin"))).to be_nil
  end

  it "does not let an assistant admin change an administrator" do
    failure = described_class.check_change(actor: administrator("silas", "assistant_admin"),
                                            target: administrator("ida", "assistant_admin"))

    expect(failure.category).to eq(:forbidden)
    expect(codes(failure)).to eq([ "admin_required" ])
  end

  it "does not let a person who does not administer the school change an administrator" do
    failure = described_class.check_change(actor: nil, target: administrator("ida", "assistant_admin"))

    expect(failure.category).to eq(:forbidden)
    expect(codes(failure)).to eq([ "admin_required" ])
  end

  it "does not let an admin change their own role or remove themselves" do
    failure = described_class.check_change(actor: admin, target: administrator("marsha", "admin"))

    expect(failure.category).to eq(:forbidden)
    expect(codes(failure)).to eq([ "own_administration" ])
  end

  it "lets only an admin invite or manage invitations" do
    expect(described_class.check_invite(actor: admin)).to be_nil
    expect(codes(described_class.check_invite(actor: administrator("silas", "assistant_admin")))).to eq([ "admin_required" ])
    expect(codes(described_class.check_invite(actor: nil))).to eq([ "admin_required" ])
  end
end
