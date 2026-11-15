# TODO

Open decisions and pending work. When a decision is made, add it to `architecture.md` and remove it here.

## Decisions

### Authorization

- What is the model: roles, policies, relationship checks (for example, "is this parent linked to this student"), or a mix?
- Authorization runs in step 3 of the command pipeline. What does that step do?
- How does a command know the actor? A field on each request, or a separate context argument (`execute(request, context)`)?
- A school administrator who is also a parent: one login with different views, or two accounts?

### Multi-tenancy

- How do we make sure each query is scoped to the correct board or school? Options:
  - scope in each repository
  - a required tenant in the request context
  - Postgres row-level security
- How do board-level access and school-level access work together?
- How do parents see a student's history at previous schools?

### Auditing and history

- Enrollment history is a requirement. Do we model it explicitly (effective-dated records) or use a general audit trail?
- What else needs an audit trail? For example: permissions, payments, role changes, data access.

### Student data privacy

- Which laws apply in our markets? For example: FERPA, COPPA, PIPEDA, provincial and state laws.
- How long do we keep data? How do we delete it when a family leaves or a contract ends?
- Do we log who accessed each student record?
- Who can give consent for a minor? At what age can students control their own permissions?

### Architecture

- Query read path: do queries always use repositories and domain entities? Or can read-optimized query objects make response DTOs directly?
- Directory and namespace layout under `app/` for each layer: by layer, by feature, or both?
- When does "production" start for the migration rules? Proposal: when we have data for the first real school.

### Product and platform

- Authentication: Rails 8 authentication with OmniAuth for Google? Cookie sessions for web, and tokens for a future mobile app?
- Mobile: a PWA with Web Push first, and React Native (Expo) only if necessary?
- Real-time updates: `config/cable.yml` uses Redis in production. Choose Solid Cable or Redis when we need real-time updates.
- Hosting and deployment.

### Test tools

- Mutation testing: Ruby (for example, `mutant`; check the license for commercial use) and JS (for example, Stryker).
- Property-based testing: Ruby (for example, `prop_check`) and JS (for example, `fast-check`).

## Actions

- [ ] Make the first git commit.
- [ ] Commit and push `language.txt` and the `testing.txt` changes in the useful_prompts repo. Then run `bin/sync-guidelines` with no override. Result: `docs/guidelines/SOURCE` records the GitHub URL.
- [ ] Configure UUIDv7 primary keys: set the generators to `uuid` and set migrations to `default: -> { "uuidv7()" }`.
- [ ] Build the base pieces:
  - [ ] `UseCaseResult` and `ValidationResult`
  - [ ] base request class
  - [ ] base command and base query, with the transaction and rollback helper
  - [ ] task scheduler, with a fake for tests
  - [ ] error rendering in `Api::V1::BaseController`
- [ ] Build one reference use case from end to end: request, command, repository, domain entity, response DTO, controller, and specs.
- [ ] Testing setup:
  - [ ] Add Playwright for browser tests of critical user journeys.
  - [ ] Add WebMock and block external network access in specs.
  - [ ] Include `ActiveSupport::Testing::TimeHelpers` in RSpec.
- [ ] Add a CI workflow at the repo root. Backend: RSpec, RuboCop, Brakeman, bundler-audit. Frontend: tests, typecheck, lint, build. Optional: `bin/sync-guidelines --check` (CI needs read access to the private useful_prompts repo, for example a deploy key).
- [ ] Add a time zone column to schools when we make the schools table.
- [ ] Before production:
  - [ ] Add `strong_migrations` and change the migration rules.
  - [ ] Set Mission Control credentials for `/jobs`.
