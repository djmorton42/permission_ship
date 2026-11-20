# typed: strict

# A person in one organization. Capability: Accounts.
class User < ApplicationRecord
  belongs_to :organization
  belongs_to :identity
  has_many :school_administrators

  validates :name, presence: true
end
