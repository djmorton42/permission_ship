# typed: strict

# The email that invites a person to administer a school. Sent by a job, so it loads
# the invitation again: a revoked or accepted invitation sends nothing.
class InvitationMailer < ApplicationMailer
  extend T::Sig

  sig { void }
  def invitation
    result = Accounts::InvitationEmailQuery.call(organization_id: params[:organization_id],
                                                 invitation_id: params[:invitation_id])
    return if result.is_a?(UseCaseResult::Failure)

    @invitation = T.let(result.value, T.nilable(Accounts::InvitationEmailQuery::InvitationEmail))
    @link = T.let(link(result.value), T.nilable(String))
    mail(to: result.value.email, subject: "You are invited to administer #{result.value.school_name}")
  end

  private

  sig { params(invitation: Accounts::InvitationEmailQuery::InvitationEmail).returns(String) }
  def link(invitation)
    token = Accounts::InvitationToken.generate(
      organization_id: params[:organization_id], invitation_id: invitation.invitation_id,
      lock_version: invitation.lock_version, expires_at: invitation.expires_at
    )
    # After #, so the token is not sent to servers or in the Referer header.
    "#{Rails.configuration.x.app_url}/invitations/accept#token=#{token}"
  end
end
