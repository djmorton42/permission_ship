# A login session. Global table. Capability: Authentication.
# organization_id is null until the person picks an organization.
class Session < ApplicationRecord
  belongs_to :identity
  belongs_to :organization, optional: true

  # A session ends this long after login. See "Session lifetime" in architecture.md.
  LIFETIME = 9.hours

  # Sessions that have not ended at the given time. Pass the time: SQL now() ignores time helpers.
  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
end
