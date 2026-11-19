# Recurring cleanup (config/recurring.yml). See Authentication::DeleteExpiredSessions.
class Authentication::DeleteExpiredSessionsJob < ApplicationJob
  queue_as :low

  def perform
    Authentication::DeleteExpiredSessions.call
  end
end
