# Sets the tenant for row-level security. See "Multi-tenancy" in ../architecture.md.
#
#   Tenancy.with_organization(organization) { School.count }
#
# Commands and queries call this. Use it directly only in the console, seeds and specs.
module Tenancy
  SETTING = "app.organization_id".freeze

  # Runs the block in a transaction with the tenant set. The previous tenant is
  # restored when the block ends, so the setting does not leak into an outer transaction.
  def self.with_organization(organization)
    organization_id = organization.respond_to?(:id) ? organization.id : organization
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

  def self.current_organization_id
    ApplicationRecord.connection.select_value("SELECT current_setting('#{SETTING}', true)").presence
  end

  def self.set(organization_id)
    ApplicationRecord.connection.select_value(
      ApplicationRecord.sanitize_sql_array([ "SELECT set_config(?, ?, true)", SETTING, organization_id.to_s ])
    )
  end

  # After a database error the transaction is aborted, and Postgres rejects every
  # statement. The rollback then drops the setting, so there is nothing to restore.
  def self.restore(organization_id)
    set(organization_id)
  rescue ActiveRecord::StatementInvalid => error
    raise unless error.cause.is_a?(PG::InFailedSqlTransaction)
  end

  private_class_method :set, :restore
end
