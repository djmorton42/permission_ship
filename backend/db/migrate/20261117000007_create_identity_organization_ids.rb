# The only cross-organization read in the app. Login uses it to find the
# organizations where an identity has a user. db/privileges.sql makes
# permishly_cross_tenant_reader (BYPASSRLS) the owner, so the function reads
# past row-level security, and lets only the app role run it.
class CreateIdentityOrganizationIds < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION identity_organization_ids(p_identity_id uuid)
      RETURNS SETOF uuid
      LANGUAGE sql STABLE SECURITY DEFINER
      SET search_path = pg_catalog, public
      AS $$
        SELECT organization_id FROM public.users WHERE identity_id = p_identity_id
      $$;
    SQL
  end

  def down
    execute "DROP FUNCTION identity_organization_ids(uuid)"
  end
end
