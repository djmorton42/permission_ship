# Base class for commands. See "Commands" in ../../architecture.md.
#
# 1. Validate the inputs. If they are not valid, return a validation failure.
# 2. Open a transaction and set the organization.
# 3. Call perform. If it returns a failure, roll back.
class ApplicationCommand
  include UseCase

  def run
    return validation_failure unless valid?

    result = nil
    ApplicationRecord.transaction do
      result = in_organization { perform }
      raise TypeError, "#{self.class.name}#perform must return a UseCaseResult" unless result.is_a?(UseCaseResult)
      raise ActiveRecord::Rollback if result.failure?
    end
    result
  end
end
