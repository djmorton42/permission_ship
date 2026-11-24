# typed: strict

# The identity for an email address, checked with its password. When the email has no
# identity, creates one with the password. Used when a person accepts an invitation:
# a new person sets a password, and a person with an account gives their password.
class Authentication::ConfirmIdentity < ApplicationCommand
  runs_without_organization

  attribute :email, :string
  attribute :password, :string
  validates :email, :password, presence: true
  # bcrypt uses only the first 72 bytes, so has_secure_password refuses longer passwords.
  validates :password, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }

  sig { override.returns(UseCaseResult[String]) }
  def perform
    identity = Identity.find_by(email:)
    return create_identity unless identity
    return incorrect_password unless identity.authenticate(password.to_s)

    success(identity.id)
  end

  private

  sig { returns(UseCaseResult[String]) }
  def create_identity
    # A savepoint, so the unique violation does not end the caller's transaction.
    success(Identity.transaction(requires_new: true) { Identity.create!(email:, password:) }.id)
  rescue ActiveRecord::RecordNotUnique
    # Another request created an identity for the email after the find_by.
    failure(:conflict, field: :email, code: "identity_created", message: "An account for this email was just created. Try again.")
  end

  sig { returns(UseCaseResult::Failure) }
  def incorrect_password
    failure(:validation, field: :password, code: "incorrect_password",
                         message: "The password is not correct for this email address.")
  end
end
