# typed: strict

# The identity's user in the organization, and the schools that user administers.
class Accounts::CurrentUserQuery < ApplicationQuery
  attribute :identity_id, :string
  validates :identity_id, presence: true

  class CurrentUser < T::Struct
    extend T::Sig

    const :name, String
    const :organization, RecordSummary
    const :administered_schools, T::Array[RecordSummary]

    sig { params(_options: T.nilable(T::Hash[Symbol, T.anything])).returns(T::Hash[String, T.anything]) }
    def as_json(_options = nil)
      { user: { name: }, organization:, administered_schools: }.as_json
    end
  end

  sig { override.returns(UseCaseResult[CurrentUser]) }
  def perform
    # Row-level security limits users to the organization.
    user = User.find_by(identity_id:)
    return failure(:not_found, code: "user_not_found", message: "User not found.") unless user

    organization = Organization.find_by!(id: organization_id)
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
