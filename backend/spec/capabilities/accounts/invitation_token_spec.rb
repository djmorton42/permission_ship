# typed: false

require "rails_helper"

RSpec.describe Accounts::InvitationToken do
  let(:organization_id) { SecureRandom.uuid }
  let(:invitation_id) { SecureRandom.uuid }

  def generate(expires_at: 7.days.from_now, lock_version: 2)
    described_class.generate(organization_id:, invitation_id:, lock_version:, expires_at:)
  end

  it "reads back the organization, the invitation and its version" do
    expect(described_class.read(generate).serialize).to eq(
      "organization_id" => organization_id, "invitation_id" => invitation_id, "lock_version" => 2
    )
  end

  it "rejects a changed token" do
    token = generate

    expect(described_class.read("#{token}x")).to be_nil
    expect(described_class.read("")).to be_nil
  end

  it "rejects a token after it expires" do
    token = generate(expires_at: 7.days.from_now)

    travel 7.days + 1.second

    expect(described_class.read(token)).to be_nil
  end
end
