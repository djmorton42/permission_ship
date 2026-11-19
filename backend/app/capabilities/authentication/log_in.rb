# Checks an email and password, and starts a session.
# If the identity has a user in one organization, the session is in that organization.
# If it has users in more than one, the person picks one (ChooseOrganization).
class Authentication::LogIn < ApplicationCommand
  runs_without_organization

  attribute :email, :string
  attribute :password, :string
  attribute :ip_address, :string
  attribute :user_agent, :string
  validates :email, :password, presence: true

  Started = Data.define(:session_id, :expires_at)

  def perform
    # authenticate_by takes the same time for an unknown email and a wrong password.
    identity = Identity.authenticate_by(email:, password:)
    return invalid_credentials unless identity

    organization_ids = Identity.organization_ids_for(identity.id)
    return no_organization if organization_ids.empty?

    now = Time.current
    session = Session.create!(
      identity:,
      organization_id: (organization_ids.first if organization_ids.one?),
      ip_address:,
      user_agent:,
      expires_at: now + Session::LIFETIME
    )
    success(Started.new(session_id: session.id, expires_at: session.expires_at))
  end

  private

  # One message for an unknown email and a wrong password, so login does not
  # reveal which email addresses have accounts.
  def invalid_credentials
    failure(:unauthenticated, code: "invalid_credentials", message: "Email or password is incorrect.")
  end

  def no_organization
    failure(:unauthenticated, code: "no_organization", message: "Your account is not part of an organization.")
  end
end
