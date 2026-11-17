# A user who administers a school. Capability: Accounts.
class SchoolAdministrator < ApplicationRecord
  belongs_to :organization
  belongs_to :school
  belongs_to :user
end
