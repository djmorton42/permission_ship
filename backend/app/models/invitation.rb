# typed: strict

# An invitation to administer a school. Capability: Accounts.
# Open until it is accepted or revoked. The link in it works until expires_at.
class Invitation < ApplicationRecord
  extend T::Sig

  # The time a new or resent invitation's link works.
  LIFETIME = T.let(7.days, ActiveSupport::Duration)

  belongs_to :organization
  belongs_to :school
  belongs_to :invited_by_user, class_name: "User", optional: true

  enum :role, { admin: "admin", assistant_admin: "assistant_admin" }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  sig { returns(T::Boolean) }
  def open? = accepted_at.nil? && revoked_at.nil?

  # True when a link with this lock_version works now: the invitation is open, it was not
  # resent or revoked after the link was made, and it has not expired.
  sig { params(lock_version: T.nilable(Integer)).returns(T::Boolean) }
  def link_works?(lock_version)
    open? && self.lock_version == lock_version && expires_at.future?
  end
end
