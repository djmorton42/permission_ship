# A login session. Global table. Capability: Authentication.
# organization_id is null until the person picks an organization.
class Session < ApplicationRecord
  belongs_to :identity
  belongs_to :organization, optional: true
end
