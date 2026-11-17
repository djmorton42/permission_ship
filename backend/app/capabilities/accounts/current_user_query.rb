# The identity's user in the organization, and the schools that user administers.
class Accounts::CurrentUserQuery < ApplicationQuery
  attribute :identity_id, :string
  validates :identity_id, presence: true

  CurrentUser = Data.define(:name, :organization, :administered_schools) do
    def as_json(*)
      { user: { name: }, organization:, administered_schools: }.as_json
    end
  end

  def perform
    # Row-level security limits users to the organization.
    user = User.find_by(identity_id:)
    return failure(:not_found, code: "user_not_found", message: "User not found.") unless user

    organization = Organization.find(organization_id)
    schools = School.joins(:school_administrators)
                    .where(school_administrators: { user_id: user.id })
                    .order(:name).pluck(:id, :name)

    success(CurrentUser.new(
      name: user.name,
      organization: RecordSummary.new(id: organization.id, name: organization.name),
      administered_schools: schools.map { |id, name| RecordSummary.new(id:, name:) }
    ))
  end
end
