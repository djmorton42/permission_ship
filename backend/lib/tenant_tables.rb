# typed: strict

# Migration helpers for tenant-owned tables. See "Multi-tenancy" in ../architecture.md.
#
#   class CreateSchools < ActiveRecord::Migration[8.1]
#     include TenantTables
#
#     def change
#       create_tenant_table :schools do |t|
#         t.string :name, null: false
#       end
#     end
#   end
module TenantTables
  extend T::Sig
  extend T::Helpers

  requires_ancestor { ActiveRecord::Migration }

  # Creates a table with a UUIDv7 primary key, an organization_id column, and a
  # forced row-level security policy for the current tenant.
  sig do
    params(
      table: Symbol,
      options: T.anything,
      block: T.nilable(T.proc.params(table: ActiveRecord::ConnectionAdapters::TableDefinition).void)
    ).void
  end
  def create_tenant_table(table, **options, &block)
    create_table(table, id: :uuid, default: -> { "uuidv7()" }, **options) do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true, index: false
      yield t if block_given?
      t.timestamps
    end

    # Other tenant tables refer to (organization_id, id). See add_tenant_reference.
    add_index table, [ :organization_id, :id ], unique: true

    reversible do |direction|
      direction.up { enable_tenant_isolation(table) }
    end
  end

  # Rows are visible and writable only when organization_id matches
  # app.organization_id (see lib/tenancy.rb). NULLIF: Postgres returns an empty
  # string for a setting that a transaction set and then ended. If the tenant
  # is not set, no rows match.
  sig { params(table: Symbol).void }
  def enable_tenant_isolation(table)
    execute <<~SQL
      ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
      ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
      CREATE POLICY tenant_isolation ON #{table}
        USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid);
    SQL
  end

  # Adds <name>_id and a foreign key on (organization_id, <name>_id).
  # Reason: a row cannot refer to a row in another organization.
  sig { params(table: Symbol, name: Symbol, to_table: T.any(String, Symbol), null: T::Boolean).void }
  def add_tenant_reference(table, name, to_table: name.to_s.pluralize, null: false)
    column = :"#{name}_id"
    add_column table, column, :uuid, null: null
    add_index table, [ :organization_id, column ]
    add_foreign_key table, to_table, column: [ :organization_id, column ], primary_key: [ :organization_id, :id ]
  end
end
