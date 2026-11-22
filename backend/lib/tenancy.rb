# typed: strict

# Sets the tenant for row-level security. See "Multi-tenancy" in ../architecture.md.
#
#   Tenancy.with_organization(organization) { School.count }
#
# Commands and queries call this. Use it directly only in the console, seeds and specs.
module Tenancy
  extend T::Sig

  SETTING = "app.organization_id"

  # Runs the block in a transaction with the tenant set. The previous tenant is
  # restored when the block ends, so the setting does not leak into an outer transaction.
  sig do
    type_parameters(:R)
      .params(organization: T.nilable(T.any(Organization, String)), block: T.proc.returns(T.type_parameter(:R)))
      .returns(T.type_parameter(:R))
  end
  def self.with_organization(organization, &block)
    organization_id = organization.is_a?(Organization) ? organization.id : organization
    raise ArgumentError, "organization is required" if organization_id.blank?

    ApplicationRecord.transaction do
      previous = current_organization_id
      set(organization_id)
      begin
        yield
      ensure
        restore(previous)
      end
    end
  end

  sig { returns(T.nilable(String)) }
  def self.current_organization_id
    ApplicationRecord.connection.select_value("SELECT current_setting('#{SETTING}', true)").presence
  end

  # Rails turns on the query cache for requests and jobs. The cache does not know the
  # tenant, so a change of tenant clears it. Otherwise a query returns rows cached for
  # another organization, and a repeated set_config comes from the cache and does not run.
  sig { params(organization_id: T.nilable(String)).void }
  def self.set(organization_id)
    connection = ApplicationRecord.connection
    connection.clear_query_cache
    connection.select_value(
      ApplicationRecord.sanitize_sql_array([ "SELECT set_config(?, ?, true)", SETTING, organization_id.to_s ])
    )
  end

  # After a database error the transaction is aborted, and Postgres rejects every
  # statement. The rollback then drops the setting, so there is nothing to restore.
  sig { params(organization_id: T.nilable(String)).void }
  def self.restore(organization_id)
    set(organization_id)
  rescue ActiveRecord::StatementInvalid => error
    raise unless error.cause.is_a?(PG::InFailedSqlTransaction)
  end

  private_class_method :set, :restore
end
