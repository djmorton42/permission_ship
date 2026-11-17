# Capability: Schools.
class School < ApplicationRecord
  belongs_to :organization
  has_many :school_administrators

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone::MAPPING.values.uniq | TZInfo::Timezone.all_identifiers }
end
