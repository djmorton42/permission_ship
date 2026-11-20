# typed: strict

# Base class for commands. See "Commands" in ../../architecture.md.
#
# 1. Validate the inputs. If they are not valid, return a validation failure.
# 2. Open a transaction and set the organization.
# 3. Call perform. If it returns a failure, roll back.
class ApplicationCommand < UseCase
  abstract!

  sig { override.returns(UseCaseResult[T.anything]) }
  def run
    return validation_failure unless valid?

    result = T.let(nil, T.nilable(UseCaseResult[T.anything]))
    ApplicationRecord.transaction do
      # T.let also checks the type at runtime, for a perform without a sig.
      performed = T.let(in_organization { perform }, UseCaseResult[T.anything])
      result = performed
      raise ActiveRecord::Rollback if performed.failure?
    end
    # The block always runs. Rails catches ActiveRecord::Rollback inside transaction.
    T.must(result)
  end
end
