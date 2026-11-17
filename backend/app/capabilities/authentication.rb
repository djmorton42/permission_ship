# Login, sessions and identities. Only this capability reads or writes identities.
module Authentication
  def self.not_logged_in
    UseCaseResult.failure(:unauthenticated, [
      UseCaseResult::Error.new(field: nil, code: "not_logged_in", message: "Log in to continue.")
    ])
  end
end
