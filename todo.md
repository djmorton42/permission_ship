# TODO

Open decisions and pending work. When a decision is made, add it to `architecture.md` and remove it here.

## Decisions

### Authorization

- What is the model: roles, policies, relationship checks (for example, "is this parent linked to this student"), or a mix?
- Authorization runs in step 3 of the command pipeline. What does that step do?
- How does a command or query know the actor? An attribute on each one, or a context argument to `call`?
- A school administrator who is also a parent in the same organization: one login with different views, or two accounts?
- Which administrative data can board admins see?

### Multi-tenancy

- Export and import: how do we move a student's records, or a whole organization, to another organization or installation?

### Auditing and history

- Enrollment history is a requirement. Do we model it explicitly (effective-dated records) or use a general audit trail?
- What else needs an audit trail? For example: permissions, payments, role changes, data access.

### Student data privacy

- Which laws apply in our markets? For example: FERPA, COPPA, PIPEDA, provincial and state laws.
- How long do we keep data? How do we delete it when a family leaves or a contract ends?
- Do we log who accessed each student record?
- Who can give consent for a minor? At what age can students control their own permissions?

### Architecture

- When does "production" start for the migration rules? Proposal: when we have data for the first real school.
- Which tool enforces capability ownership, and when? For example, `packwerk`.

### Product and platform

- Authentication: Rails 8 authentication with OmniAuth for Google? Cookie sessions for web, and tokens for a future mobile app? (The login and organization picker rules are in `architecture.md`.)
- Mobile: a PWA with Web Push first, and React Native (Expo) only if necessary?
- Real-time updates: `config/cable.yml` uses Redis in production. Choose Solid Cable or Redis when we need real-time updates.
- Hosting and deployment.

### Test tools

- Mutation testing: Ruby (for example, `mutant`; check the license for commercial use) and JS (for example, Stryker).
- Property-based testing: Ruby (for example, `prop_check`) and JS (for example, `fast-check`).

## Actions

- [ ] Push the useful_prompts repo. Then run `bin/sync-guidelines` with no override. Result: `docs/guidelines/SOURCE` records the GitHub URL.
- [ ] Configure UUIDv7 primary keys: set the generators to `uuid` and set migrations to `default: -> { "uuidv7()" }`.
- [ ] Turn on `strict_loading_by_default`.
- [ ] Set up multi-tenancy before the first tenant table:
  - [ ] Create the `organizations` table.
  - [ ] Create two database roles: an owner role for migrations and an app role that RLS applies to. Do this in local Docker, CI, and production.
  - [ ] Change the schema format to `structure.sql`.
  - [ ] Write the RLS migration helper (column, forced RLS, policy, index).
  - [ ] Set `app.organization_id` with `SET LOCAL` in `ApplicationCommand` and `ApplicationQuery`. Run queries in a read-only transaction.
  - [ ] Add a console helper, `with_organization(org) { ... }`.
  - [ ] Add spec support: a tenant helper and a shared isolation example that runs as the app role.
  - [ ] Write the login lookup database function.
- [ ] Build the base pieces:
  - [ ] `UseCaseResult`
  - [ ] `ApplicationCommand`: attributes, validation, the `dependency` helper, the transaction and rollback
  - [ ] `ApplicationQuery`: attributes, validation, the `dependency` helper, no writes
  - [ ] error rendering in `Api::V1::BaseController`
  - [ ] the `app/capabilities/` directory
- [ ] Build one reference capability from end to end: command, query, model, response DTO, controller, React screen, and specs.
- [ ] Build `Idempotency-Key` support (storage, controller support, React header) before the first payment or notification command.
- [ ] Testing setup:
  - [ ] Add Playwright for browser tests of critical user journeys.
  - [ ] Add WebMock and block external network access in specs.
  - [ ] Include `ActiveSupport::Testing::TimeHelpers` in RSpec.
- [ ] Add a CI workflow at the repo root. Backend: RSpec, RuboCop, Brakeman, bundler-audit. Frontend: tests, typecheck, lint, build. Optional: `bin/sync-guidelines --check` (CI needs read access to the private useful_prompts repo, for example a deploy key).
- [ ] Add a time zone column to schools when we make the schools table.
- [ ] Before production:
  - [ ] Add `strong_migrations` and change the migration rules.
  - [ ] Set Mission Control credentials for `/jobs`.
