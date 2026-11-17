-- Database roles and privileges. Applied by `bin/rails db:privileges`, which runs
-- after db:migrate, db:schema:load, db:prepare and db:test:prepare.
-- structure.sql does not store privileges or owners, so they are here.
-- Every statement must be idempotent.

-- The app connects as permishly_app. Row-level security applies to it.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'permishly_app') THEN
    CREATE ROLE permishly_app LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
  -- Owns functions that read across organizations (see identity_organization_ids).
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'permishly_cross_tenant_reader') THEN
    CREATE ROLE permishly_cross_tenant_reader NOLOGIN BYPASSRLS;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO permishly_app, permishly_cross_tenant_reader;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO permishly_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO permishly_app;

-- Login: list the organizations where an identity has a user.
GRANT CREATE ON SCHEMA public TO permishly_cross_tenant_reader;
GRANT SELECT (identity_id, organization_id) ON users TO permishly_cross_tenant_reader;
ALTER FUNCTION identity_organization_ids(uuid) OWNER TO permishly_cross_tenant_reader;
REVOKE ALL ON FUNCTION identity_organization_ids(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION identity_organization_ids(uuid) TO permishly_app;
