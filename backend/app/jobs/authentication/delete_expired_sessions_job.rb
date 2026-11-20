# typed: strict

# Recurring cleanup (config/recurring.yml). See Authentication::DeleteExpiredSessions.
class Authentication::DeleteExpiredSessionsJob < ApplicationJob
  extend T::Sig

  queue_as :low

  sig { void }
  def perform
    Authentication::DeleteExpiredSessions.call
  end
end
