# typed: strict

# Login credentials for a person. Global table. Capability: Authentication.
# Only the Authentication capability reads or writes identities.
class Identity < ApplicationRecord
  extend T::Sig

  has_secure_password
  has_many :sessions

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true

  # The organizations where the identity has a user. This is the only read
  # across organizations. It uses the identity_organization_ids database function.
  sig { params(identity_id: T.nilable(String)).returns(T::Array[String]) }
  def self.organization_ids_for(identity_id)
    connection.select_values(sanitize_sql_array([ "SELECT identity_organization_ids(?)", identity_id ]))
  end
end
