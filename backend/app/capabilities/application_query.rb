# Base class for queries. See "Queries" in ../../architecture.md.
#
# A query runs in a read-only transaction with the organization set, and
# Active Record prevents writes.
class ApplicationQuery
  include UseCase

  def run
    return validation_failure unless valid?

    # Only the first statement of a transaction can make it read-only. A query
    # inside a command joins the command's transaction, so it skips this.
    read_only = !ApplicationRecord.connection.transaction_open?
    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute("SET TRANSACTION READ ONLY") if read_only
      in_organization { ActiveRecord::Base.while_preventing_writes { perform } }
    end
  end
end
