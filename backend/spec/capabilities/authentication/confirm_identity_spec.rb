# typed: false

require "rails_helper"

RSpec.describe Authentication::ConfirmIdentity do
  it "creates an identity with the password when the email has none" do
    result = described_class.call(email: "Zadok.Allen@example.com ", password: "a long password")

    expect(result).to be_success
    identity = Identity.find(result.value)
    expect(identity.email).to eq("zadok.allen@example.com")
    expect(identity.authenticate("a long password")).to be_truthy
  end

  it "returns the existing identity when the password is correct" do
    identity = create_identity(email: "zadok.allen@example.com", password: "a long password")

    result = described_class.call(email: "zadok.allen@example.com", password: "a long password")

    expect(result.value).to eq(identity.id)
  end

  it "rejects a wrong password for an existing identity, and does not change it" do
    identity = create_identity(email: "zadok.allen@example.com", password: "a long password")

    result = described_class.call(email: "zadok.allen@example.com", password: "another password")

    expect(result.category).to eq(:validation)
    expect(result.errors.map(&:to_h)).to eq([ { field: "password", code: "incorrect_password",
                                                message: "The password is not correct for this email address." } ])
    expect(identity.reload.authenticate("a long password")).to be_truthy
  end

  it "requires a password" do
    result = described_class.call(email: "zadok.allen@example.com", password: "")

    expect(result.errors.map(&:field)).to eq([ "password" ])
  end

  it "refuses a password that is too long to store" do
    result = described_class.call(email: "zadok.allen@example.com", password: "a" * 73)

    expect(result.errors.map(&:field)).to eq([ "password" ])
    expect(Identity.count).to eq(0)
  end
end
