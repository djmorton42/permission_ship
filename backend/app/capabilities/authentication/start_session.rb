# typed: strict

# Starts a session for an identity, in an organization where it has a user, or with
# no organization (the person picks one later, with ChooseOrganization).
class Authentication::StartSession < ApplicationCommand
  runs_without_organization

  attribute :identity_id, :string
  # organization_id (from ApplicationCommand) is the session's organization, or nil.
  attribute :ip_address, :string
  attribute :user_agent, :string
  validates :identity_id, presence: true

  class Started < T::Struct
    const :session_id, String
    const :expires_at, ActiveSupport::TimeWithZone
  end

  sig { override.returns(UseCaseResult[Started]) }
  def perform
    if organization_id && !Identity.organization_ids_for(identity_id).include?(organization_id)
      return failure(:forbidden, field: :organization_id, code: "not_a_member",
                                 message: "You are not a member of this organization.")
    end

    now = Time.current
    session = Session.create!(identity_id:, organization_id:, ip_address:, user_agent:,
                              expires_at: now + Session::LIFETIME, last_active_at: now)
    success(Started.new(session_id: session.id, expires_at: session.expires_at))
  end
end
