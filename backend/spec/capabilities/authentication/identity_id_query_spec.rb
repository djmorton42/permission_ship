# typed: false

require "rails_helper"

RSpec.describe Authentication::IdentityIdQuery do
  it "finds the identity by email, in any case" do
    identity = create_identity(email: "zadok.allen@example.com", password: "a long password")

    expect(described_class.call(email: " Zadok.Allen@Example.com ").value).to eq(identity.id)
  end

  it "returns nil for an email without an identity" do
    expect(described_class.call(email: "nobody@example.com").value).to be_nil
  end
end
