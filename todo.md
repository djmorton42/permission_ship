# TODO

Open decisions and pending work. When a decision is made, add it to `architecture.md` and remove it here.

## Decisions

### Authorization

- A school administrator who is also a parent in the same organization: one login with different views, or two accounts? `users` has a unique index on `(organization_id, identity_id)`, so now it is one user with two relationships. Two users in one organization needs a change to the index and to the organization picker. Decide before real user rows exist.
- Which administrative data can board admins see?

### Multi-tenancy

- Export and import: how do we move a student's records, or a whole organization, to another organization or installation?

### Auditing and history

- Enrollment history is a requirement. Do we model it explicitly (effective-dated records) or use a general audit trail?
- What else needs an audit trail? For example: permissions, payments, data access. (Changes to school administrators are decided.)
- Which reads are sensitive enough to audit? For example: student records, medical and contact details, exports. (How we record audited reads is in "Auditing" in `architecture.md`.)
- Which audited reads must fail when the audit record cannot be written?
- How does a query result give its subject IDs (for example, which students) to the caller that writes the audit record?

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
- Sessions: do boards need their own session limits, or a "This is a shared computer" option at login with a shorter timeout? Now every session has a 30-minute idle timeout and a 9-hour limit (see "Session lifetime" in `architecture.md`).
- Password rules: minimum length, and a check against breached passwords?
- MFA: required for administrators? Which method (TOTP, passkeys)?
- Authorization inside an organization: row-level security separates organizations only. A school administrator and a parent in the same organization see the same rows unless a command checks the actor. The first student, parent or payment table needs an actor and a policy on the command.
- Password reset: who can reset a password? An identity is global, and it can have users in more than one organization. A reset by an administrator of one organization also changes access to the other organizations. Options:
  - Only the person, with a reset link sent to the identity's email address.
  - An administrator can send the reset link, but cannot set the password.
  - An administrator can set the password only when the identity has users in that organization and in no other.
  - Related: who can change the identity's email address? A change of email address gives control of the identity, so it has the same problem.
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
- [ ] Add a concurrency spec for two admins who demote each other at the same time. It needs a spec without the wrapping transaction, and cleanup as the owner role, because the app role cannot delete audit events.
- [ ] When board administrators can change a school's administrators, add a "last admin" check. Now the rule follows from "an admin who is not the target" (see "School administrators" in `architecture.md`).
- [ ] Add commands to create organizations, schools, users and school administrators. Then make `db/seeds/demo_data.rb` use them.
- [ ] School administrator roles and invitations. When each part is built, move its rules to `architecture.md`. Pull requests, in order:
  1. Audit events: who changed what, and when. Built.
  2. Authorization and roles: the actor on commands and queries, a policy, the `admin` and `assistant_admin` roles, and commands to change a role and to remove an administrator. Built.
  3. Send invitations: invite, the invitation email, and a rake task for the operations team. Built.
  4. Resend and revoke invitations. Built.
  5. Accept invitations (API): a new identity sets a password, an existing identity gives its password. Built.
  6. The invitation page in React, and an e2e test that opens the email in Mailpit.
  7. A screen to manage a school's administrators.

  Decided rules:
  - Roles are per school. A board administrator role comes later.
  - An admin can invite admins and assistant admins, promote and demote other administrators, and remove them.
  - An assistant admin does other administration tasks (for example, adding students). An assistant admin does not invite or remove administrators.
  - Nobody changes their own role or removes themselves.
  - A school always has at least one admin. A pending invitation does not count.
  - People join only by invitation email. The invitee sets their own password. An existing identity logs in to accept.
  - An invitation token is single-use and expires after 7 days. Resend makes a new token and cancels the old one. An admin can revoke an invitation.
  - An invitation for a person who is already an administrator of the school is refused. Change the role instead.
  - A school without a board administrator gets its first admin from the operations team, through a rake task. The audit record shows the operator and a reference (for example, a ticket number).
  - Every role change, invitation, acceptance, revocation and removal writes an audit event: the actor, the change (before and after), the subject and the time.
- [ ] Production email: use Amazon SES. Set it up before the first deployed environment. Also set `APP_URL` (links in emails) and the sender address (`ApplicationMailer` sends from `from@example.com`).
- [ ] Add a serializer for response DTOs. DTOs define `as_json` for now.
- [ ] Build `Idempotency-Key` support (storage, controller support, React header) before the first payment or bulk notification command. Invitations use natural keys instead (see "Invitations" in `architecture.md`).
- [ ] Testing setup:
  - [ ] Add WebMock and block external network access in specs.
- [ ] Add `bin/sync-guidelines --check` to CI. CI needs read access to the private useful_prompts repo (for example, a deploy key).
- [ ] Authentication security (gaps found after the first login feature):
  - [ ] Rate limit: also limit by account, not only by IP address. Configure a shared production cache store, because `rate_limit` keeps its counts in `Rails.cache` and the default file store is per machine. Deny the login when the counter does not increment (a null store now disables the limit). Set the trusted proxies, so `request.remote_ip` is the client address.
  - [ ] Sessions: when a login starts a new session, older sessions of that identity stay valid until they end. The stored IP address and user agent are never compared.
  - [ ] Creating a user for an email that already has an identity: send an invitation that the person accepts. Do not attach the existing identity directly. Development seeds can keep creating rows directly.
  - [ ] When a user is removed: end or move the sessions in that organization. Now `GET /api/v1/session` returns 401 even if the identity has another organization. When the identity has no users left, delete it and its sessions.
  - [ ] Before the first deployed environment: refuse to boot when the `primary` database role has `rolbypassrls` or is a superuser. Set `config.hosts`. Decide whether `GET /api/v1/health` stays public (it reports database and job status).
  - [ ] Password reset (see "Password reset" above).
  - [ ] End all sessions of an identity when its password changes.
  - [ ] Audit log of logins, failed logins and logouts (see "Auditing and history").
  - [ ] Security review by another person (for example, `/security-review` or a pen test) before real student data.
- [ ] Rename the internal name Permishly to Permission Ship. The app shows the new name, logos and colours already (`etc/brand/`). Still old:
  - [ ] The Rails app module (`module Permishly` in `config/application.rb`), and `permishly-api` in `backend/Dockerfile`.
  - [ ] Database names (`permishly_development`, `permishly_test`, `permishly_production`) and roles (`permishly` owner, `permishly_app`, `permishly_cross_tenant_reader`): `database.yml`, `cable.yml`, `docker-compose.yml`, `db/privileges.sql`, the `identity_organization_ids` migration, and `.github/workflows/ci.yml`. A role rename in a migration needs a new migration, not an edit. Existing local databases need a rebuild.
  - [ ] `permishly-frontend` in `frontend/package.json`.
  - [ ] The demo password `permishly-demo` (`db/seeds/demo_data.rb`, specs, Playwright and Vitest tests, README).
  - [ ] Docs: `README.md`, `architecture.md`, `CLAUDE.md`, `todo.md`. Leave the dated walkthroughs in `docs/walkthroughs/` as they are.
  - [ ] The local directory (`~/source/permishly`). The GitHub repository is `permission_ship` already.
- [ ] Before production:
  - [ ] Add `strong_migrations` and change the migration rules.
  - [ ] Set Mission Control credentials for `/jobs`.
