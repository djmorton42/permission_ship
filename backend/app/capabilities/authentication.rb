# Login, sessions and identities. Only this capability reads or writes identities.
module Authentication
  def self.not_logged_in
    UseCaseResult.failure(:unauthenticated, [
      UseCaseResult::Error.new(field: nil, code: "not_logged_in", message: "Log in to continue.")
    ])
  end

  # The session has no organization yet. The person picks one (ChooseOrganization).
  def self.organization_required
    UseCaseResult.failure(:forbidden, [
      UseCaseResult::Error.new(field: nil, code: "organization_required", message: "Choose an organization to continue.")
    ])
  end
end
