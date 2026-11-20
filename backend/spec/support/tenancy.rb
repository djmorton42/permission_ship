# typed: false

module TenancyHelpers
  # Creates records in an organization. The tenant is cleared when the block ends.
  def in_organization(organization, &)
    Tenancy.with_organization(organization, &)
  end
end

RSpec.configure do |config|
  config.include TenancyHelpers
end
