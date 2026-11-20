# typed: false

module AccountHelpers
  def create_identity(email:, password:)
    Identity.create!(email:, password:)
  end

  # Gives the identity a user in the organization who administers the schools.
  def create_school_administrator(identity:, organization:, name:, schools: [])
    in_organization(organization) do
      user = User.create!(organization:, identity:, name:)
      schools.each { |school| SchoolAdministrator.create!(organization:, school:, user:) }
      user
    end
  end

  def create_school(organization:, name:, time_zone: "America/Toronto")
    in_organization(organization) { School.create!(organization:, name:, time_zone:) }
  end
end

RSpec.configure do |config|
  config.include AccountHelpers
end
