# typed: false

# A school with administrators in given roles, for specs of commands that change administrators.
module AdministratorHelpers
  # Adds a user to the school in the role. Returns the SchoolAdministrator.
  def add_school_administrator(school:, name:, role:)
    email = "#{name.parameterize(separator: '.')}@example.com"
    user = create_school_administrator(identity: create_identity(email:, password: "a long password"),
                                       organization: school.organization, name:)
    in_organization(school.organization) { SchoolAdministrator.create!(organization: school.organization, school:, user:, role:) }
  end

  def audit_events(organization) = in_organization(organization) { AuditEvent.order(:created_at).to_a }
end

RSpec.configure do |config|
  config.include AdministratorHelpers
end
