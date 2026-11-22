# typed: strict

# The token in an invitation link: the organization, the invitation and its lock_version,
# signed with the app's secret, until the invitation expires.
#
# The database does not store the token. The mail job makes it when it renders the email.
# Resend and revoke change lock_version, so older tokens stop working. Acceptance reads
# the organization from the token, then loads the invitation in that organization.
module Accounts::InvitationToken
  extend T::Sig

  PURPOSE = "invitation"

  class Payload < T::Struct
    const :organization_id, String
    const :invitation_id, String
    const :lock_version, Integer
  end

  sig { params(organization_id: String, invitation_id: String, lock_version: Integer, expires_at: ActiveSupport::TimeWithZone).returns(String) }
  def self.generate(organization_id:, invitation_id:, lock_version:, expires_at:)
    verifier.generate([ organization_id, invitation_id, lock_version ], purpose: PURPOSE, expires_at:)
  end

  # Nil when the token is changed, expired, or not an invitation token.
  sig { params(token: String).returns(T.nilable(Payload)) }
  def self.read(token)
    organization_id, invitation_id, lock_version = verifier.verified(token, purpose: PURPOSE)
    return nil unless organization_id.is_a?(String) && invitation_id.is_a?(String) && lock_version.is_a?(Integer)

    Payload.new(organization_id:, invitation_id:, lock_version:)
  end

  sig { returns(ActiveSupport::MessageVerifier) }
  def self.verifier = Rails.application.message_verifier(PURPOSE)
  private_class_method :verifier
end
