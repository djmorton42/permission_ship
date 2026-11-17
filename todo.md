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

- Authentication: OmniAuth for Google? Tokens for a future mobile app? (Password login with cookie sessions is in `architecture.md`.)
- Sessions: when does a session expire? The cookie is permanent, and the server does not end old sessions.
- CSRF: `SameSite=Lax` is the only protection for cookie-authenticated writes. Do we also need a CSRF token or an `Origin` check?
- Mobile: a PWA with Web Push first, and React Native (Expo) only if necessary?
- Real-time updates: `config/cable.yml` uses Redis in production. Choose Solid Cable or Redis when we need real-time updates.
- Hosting and deployment.

### Test tools

- Mutation testing: Ruby (for example, `mutant`; check the license for commercial use) and JS (for example, Stryker).
- Property-based testing: Ruby (for example, `prop_check`) and JS (for example, `fast-check`).

## Actions

- [ ] Push the useful_prompts repo. Then run `bin/sync-guidelines` with no override. Result: `docs/guidelines/SOURCE` records the GitHub URL.
- [ ] Set up the database roles in CI and production. Production needs `PRIMARY_DATABASE_URL` (app role) and `OWNER_DATABASE_URL` (owner role), and a password for `permishly_app`.
- [ ] Add a shared spec example for tenant isolation, so each query spec does not write its own.
- [ ] Add commands to create organizations, schools, users and school administrators. Then make `db/seeds/demo.rb` use them.
- [ ] Add a serializer for response DTOs. DTOs define `as_json` for now.
- [ ] Build `Idempotency-Key` support (storage, controller support, React header) before the first payment or notification command.
- [ ] Testing setup:
  - [ ] Add Playwright for browser tests of critical user journeys.
  - [ ] Add WebMock and block external network access in specs.
  - [ ] Include `ActiveSupport::Testing::TimeHelpers` in RSpec.
- [ ] Add a CI workflow at the repo root. Backend: RSpec, RuboCop, Brakeman, bundler-audit. Frontend: tests, typecheck, lint, build. Optional: `bin/sync-guidelines --check` (CI needs read access to the private useful_prompts repo, for example a deploy key).
- [ ] Before production:
  - [ ] Add `strong_migrations` and change the migration rules.
  - [ ] Set Mission Control credentials for `/jobs`.
