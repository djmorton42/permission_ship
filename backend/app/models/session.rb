# typed: strict

# A login session. Global table. Capability: Authentication.
# organization_id is null until the person picks an organization.
class Session < ApplicationRecord
  belongs_to :identity
  belongs_to :organization, optional: true

  # A session ends this long after login. See "Session lifetime" in architecture.md.
  LIFETIME = T.let(9.hours, ActiveSupport::Duration)
  # A session also ends after this long without a request.
  IDLE_TIMEOUT = T.let(30.minutes, ActiveSupport::Duration)

  # Sessions that have not ended at the given time. Pass the time: SQL now() ignores time helpers.
  scope :active_at, ->(time) {
    where(arel_table[:expires_at].gt(time)).where(arel_table[:last_active_at].gt(time - IDLE_TIMEOUT))
  }
end
