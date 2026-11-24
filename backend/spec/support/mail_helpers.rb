# typed: false

# Mail is sent by jobs. Run the jobs with perform_enqueued_jobs, then read ActionMailer::Base.deliveries.
module MailHelpers
  def sent_mail = ActionMailer::Base.deliveries

  # The token from the invitation link in an email (the link puts it after #token=).
  def invitation_token(mail)
    mail.text_part.body.decoded[%r{/invitations/accept#token=(\S+)}, 1]
  end
end

RSpec.configure do |config|
  config.include ActiveJob::TestHelper
  config.include MailHelpers
  config.before { ActionMailer::Base.deliveries.clear }
end
