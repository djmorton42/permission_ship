# Architecture

Architecture rules for Permishly. Open decisions and pending work are in `todo.md`.

## Overview

- The backend is a modular Rails application. Code is organized by business capability.
- Commands do writes. Queries do reads (CQRS).
- Commands and queries use Active Record directly.
- Commands and queries use the same database. Reason: a write is visible to the next query immediately.
- We do not use event sourcing, a command bus, separate read stores, or asynchronous command processing by default. Add one only when a concrete requirement needs it.
- General coding rules are in `docs/guidelines/coding.txt`. This file adds the rules for this project.

| Component | Responsibility |
| --- | --- |
| React | Interaction, presentation state, and user-facing validation. Sends business intent. Shows query results. |
| Rails controllers | Convert HTTP input into a command or query call. Map the result to an HTTP response. |
| Commands | Coordinate authorization, transactions, loading, business rules, persistence, and jobs. |
| Models and policies | Own invariants, calculations, eligibility rules, and valid state changes. |
| Queries | Do efficient reads. Return read models or response DTOs. |
| Jobs | Run deferred work by calling commands. |

## Capabilities

- Each business capability has a namespace. Examples: `Enrollments`, `FieldTrips`, `Notifications`.
- Commands, queries, policies, and DTOs live in `app/capabilities/<capability>/`. `UseCaseResult` and shared DTOs (`RecordSummary`) are in `app/lib/`. Example: `app/capabilities/enrollments/enroll_student.rb` defines `Enrollments::EnrollStudent`.
- Active Record models stay in `app/models`. Each model belongs to one capability.
- Only a capability's own commands write its models. Other capabilities call its commands. Reason: each piece of state has one owner.
- Queries can read across capabilities.
- We enforce ownership by convention. A tool to enforce it is in `todo.md`.

## Multi-tenancy

- An organization is the tenant. A school board is an organization. An independent school is an organization with one school.
- The same code supports one organization per installation or many organizations in one installation.
- Every tenant-owned table has an `organization_id` column. This includes users.
- A table whose data belongs to one school also has a `school_id` column.
- Global tables have no `organization_id`: `organizations`, `identities`, and infrastructure tables (for example, Solid Queue tables).
- A user belongs to one organization. A person in two organizations has two users, one in each organization, with separate roles and data.
- A person has one identity for login (see Login).
- Data does not cross organizations. A student who moves to another organization starts with no history there. (An export and import process is in `todo.md`.)
- Within an organization, roles and policies control access to schools and to student data. This is authorization, not tenancy. Example: board admins see administrative data, but not individual student data.

### Row-level security

Postgres row-level security (RLS) enforces the organization boundary. Reason: a query that forgets its tenant filter cannot leak data.

- Every tenant-owned table has RLS enabled and forced, with this policy:

  ```sql
  USING (organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid)
  ```

  If the tenant is not set, no rows match. `NULLIF`: after a transaction ends, Postgres returns an empty string for the setting.
- Create tenant tables with `create_tenant_table` (`lib/tenant_tables.rb`). It adds the column, the policy, and the `(organization_id, id)` unique index. Add references between tenant tables with `add_tenant_reference`.
- `Tenancy.with_organization(org) { ... }` (`lib/tenancy.rb`) sets the tenant for a block, in a transaction. It restores the previous tenant when the block ends. Commands and queries use it. Use it directly only in the console, seeds, and specs.
- `ApplicationCommand` and `ApplicationQuery` set the tenant from their `organization_id` input. The setting ends with the block.
- Queries run in a read-only transaction.
- Jobs take `organization_id` as an argument and pass it to the command.
- Foreign keys between tenant tables include `organization_id`. Reason: a row cannot refer to a row in another organization.
- Indexes on tenant tables start with `organization_id`.
- The schema format is `structure.sql`. Reason: `schema.rb` cannot store RLS policies.
- Only named platform tools (support scripts, cross-organization reports) use a database role that bypasses RLS.

### Database roles

| Role | Used by | RLS |
| --- | --- | --- |
| Owner (`permishly` locally) | `db:` tasks: migrations, schema loads, seeds | Bypasses (superuser locally) |
| `permishly_app` | The app, jobs, and specs (`primary` in `config/database.yml`) | Applies |
| `permishly_cross_tenant_reader` | Owns `identity_organization_ids`. Cannot log in. | Bypasses |

- `config/database.yml` has two configs for each database: `primary` (app role, `database_tasks: false`) and `owner`.
- `db/privileges.sql` creates the roles and grants their privileges. Reason: `structure.sql` does not store privileges or owners. Every statement in it is idempotent.
- `bin/rails db:privileges` applies the file. It runs after `db:migrate`, `db:schema:load`, `db:prepare`, `db:rollback`, and `db:test:prepare`.
- When you add a table, the app role gets access the next time the task runs. When you add a database function that needs a special owner or grant, add it to `db/privileges.sql`.

### Identities and login

Credentials are in a global `identities` table. Reason: a person has one password, one reset flow, and one MFA setup, and login checks one password.

| Table | Tenant | Contains |
| --- | --- | --- |
| `identities` | No (global) | Email, password digest, Google ID, MFA settings, lockout state |
| `users` | Yes (`organization_id`, RLS) | `identity_id`, name, roles, and all data about the person in that organization |

- `identities` contains only the data needed to authenticate. It contains no tenant data.
- Only the authentication capability reads or writes `identities`.
- When an identity has no users, delete it. Example: after an organization is deleted.
- An export does not include credentials. Users set a new password or accept an invitation in the new installation.
- Login flow:
  1. The person authenticates with a password against `identities` (`POST /api/v1/session`).
  2. The server finds the organizations where the identity has a user. This is the only cross-organization read in the app. It uses the `identity_organization_ids` database function, not the RLS bypass role.
  3. If there is one organization, the session is in it.
  4. If there is more than one, the person picks an organization (`POST /api/v1/session/organization`).
- `GET /api/v1/session` returns the signed-in user, or the organizations to pick from.
- `sessions` is a global table. A session has an `identity_id` and an `organization_id`, which is null until the person picks one.
- The session ID is in a signed, `HttpOnly`, `SameSite=Lax` cookie. Reason: JavaScript cannot read it, and browsers do not send it with cross-site POST requests.
- Login is rate limited: 10 attempts in 3 minutes for each IP address.
- Login never shows organizations before authentication succeeds. Reason: that would reveal which organizations an email address belongs to.

### Signed-in requests

`BaseController` finds the session once, before the action (`SignedInSession`, in `app/controllers/concerns/`).

- By default, every action needs a session and an organization. Without a session, the response is 401 `not_logged_in`. Without an organization, the response is 403 `organization_required`. Reason: a new endpoint is protected even if its author forgets.
- A controller opts out for named actions only:
  - `allow_without_session only: ...`: login, logout, health, and the development demo accounts.
  - `allow_without_organization only: ...`: the session read and the organization picker, which run before the person picks an organization.
- Pass `organization_inputs(inputs)` to commands and queries. It sets `organization_id` from the session. An `organization_id` in the request never replaces it. Reason: row-level security shows the organization the app sets, so the app must set the session's organization.
- `POST /api/v1/session/organization` is the only action that reads an organization ID from the request. `ChooseOrganization` checks that the identity has a user there.
- `current_session` has the session ID, the identity ID, and the organization ID.
- Pass `actor_inputs(inputs)` to commands and queries that authorize the person. It adds `actor_user_id`: the session's user in the organization, or nil when the identity has no user there (`Accounts::ActorQuery`).

### Session lifetime

A session ends at the first of these times:

| Limit | Value | Reason |
| --- | --- | --- |
| Idle timeout (`Session::IDLE_TIMEOUT`) | 30 minutes without a request | School computers are shared. A person can walk away without logging out. |
| Absolute limit (`Session::LIFETIME`) | 9 hours after login | A session never lasts forever, even when it is in use, and a copied cookie stops working. 9 hours covers a working day. |

- The server decides. `sessions.expires_at` is the absolute end time, and `sessions.last_active_at` is the time of the last request. A session past either limit is not logged in, everywhere the app reads a session (`Session.active_at`).
- Every signed-in request sets `last_active_at` (`Authentication::RecordSessionActivity`, run by `SignedInSession`). This includes GET requests.
- Do not let background requests, for example polling or automatic refreshes, keep a session alive. Reason: they make requests when nobody is at the computer. A feature that needs them must not count them as activity.
- The cookie expires at the absolute end time, so the browser deletes it. The expiry is also in the signed cookie value, so Rails rejects an old cookie that a client still sends. The idle timeout is on the server only.
- `Authentication::DeleteExpiredSessionsJob` deletes ended sessions every hour (`config/recurring.yml`).

### Sessions and CSRF

`SameSite=Lax` stops the browser from sending the session cookie with a cross-site POST. It does not stop a cross-site POST from setting a new cookie. Without more protection, a form on another site could log the browser in to an attacker's account (login CSRF).

- Every API request except `GET`, `HEAD` and `OPTIONS` must have an `Origin` header. The value must be the API's own origin, or an origin in `config.x.allowed_origins`. Otherwise the response is 403 `origin_not_allowed`. A request with no `Origin` is rejected. Reason: browsers send `Origin` with all of these requests.
- `POST`, `PUT` and `PATCH` must send `Content-Type: application/json`. Otherwise the response is 415 `json_required`. Reason: an HTML form cannot send JSON, and a cross-origin `fetch` with JSON needs a CORS preflight.
- `config.x.allowed_origins` comes from `CORS_ORIGINS`. CORS uses the same list. In production, the list is empty when `CORS_ORIGINS` is not set. Development and test allow the Vite servers, because the Vite proxy keeps the browser's `Origin`.
- `GET` requests must not change data. Reason: they are not checked. The one exception is session activity (`last_active_at`), which is not data the person controls.
- API responses send `Cache-Control: no-store`. Reason: responses contain a person's data, and school computers are shared.
- `CrossSiteRequestProtection` (`app/controllers/concerns/`) does the checks. Request specs send writes with `api_post` and `api_delete`, which send JSON from the API's own origin.
- Tools such as `curl` must send an `Origin` header for writes, for example `-H 'Origin: http://localhost:5173'`.

## Commands

- Every consequential write goes through a command. This includes writes from controllers, jobs, rake tasks, and admin tools.
- Name commands for business intent. Example: `FieldTrips::ApprovePermission`, not `FieldTrips::UpdatePermission`. A simple edit can be a plain update command.
- A workflow usually maps to one command. A command can call other commands.
- Commands inherit from `ApplicationCommand`.
- A command declares its inputs with `attribute` and validates them with `validates`.
- Every command has an `organization_id` input, and it is required. A global command (for example, login) calls `runs_without_organization`.
- A command declares its dependencies with `dependency` (see Dependencies).
- `perform` has a signature that gives the type of its result (see Types).
- `Command.call(inputs, **dependencies)` runs the command and returns a `UseCaseResult`. `Command.call(**keywords)` also works: keywords that name a declared dependency are dependencies, and the others are inputs.
- A command can return data, for example the ID of a new record or a small outcome payload.

```ruby
class Enrollments::EnrollStudent < ApplicationCommand
  attribute :student_id, :string
  attribute :school_id, :string
  attribute :starts_on, :date
  validates :student_id, :school_id, :starts_on, presence: true

  dependency :push_gateway, type: PushGateway, default: -> { PushGateway.new }

  sig { override.returns(UseCaseResult[NilClass]) }
  def perform
    # load, authorize, check rules, write
    success(nil)
  end
end

Enrollments::EnrollStudent.call(enroll_params)
```

### Command steps

`ApplicationCommand` runs these steps in this order:

1. Validate the inputs. If they are not valid, return a `validation` failure.
2. Open a transaction (see Transactions) and set the tenant.
3. Call `perform`, which:
   1. loads data;
   2. authorizes the actor (see Authorization);
   3. checks business rules;
   4. writes.

Steps 2 and 3 run in one transaction.

### Authorization

- The actor is a user. A command or query that authorizes declares `attribute :actor_user_id, :string`. Controllers set it with `actor_inputs`. Do not take it from the request.
- A nil actor has no permissions. The authorization check refuses it.
- Authorization rules are in a policy in the capability, for example `Accounts::AdministratorPolicy`. A policy check returns nil when the action is allowed, or a `forbidden` failure.
- Rules can use roles and relationships (for example, "is this parent linked to this student").

### School administrators

- A school administrator (`school_administrators`) has a role in one school: `admin` or `assistant_admin`.
- Only an admin of the school changes its administrators. Nobody changes their own role or removes themselves (`Accounts::AdministratorPolicy`).
- These rules keep at least one admin in every school, because the actor is an admin who stays. Commands lock the school's administrators (`SchoolAdministrator.locked_for_school`) before the check. Reason: two admins cannot demote each other at the same time.
- Every change writes an audit event.

### Business rules

- Put a rule that applies to one record on its model, as a plain method or a validation. Do not use a callback.
- Put a rule that spans records, or that more than one command uses, in a policy object in its capability. Do not copy rules between commands.
- Protect a check that guards a write with a row lock, `lock_version`, or a database constraint. Example: "Is there space on the field trip?"

### Idempotency

- The idempotency key for commands that cost money or contact people is the `Idempotency-Key` header. React makes a new UUID for each submission.
- Example of a natural key: one permission slip for each student and trip.

## Queries

- Queries inherit from `ApplicationQuery`. They use the same `attribute`, `validates`, and `call` shape as commands.
- Queries use Active Record or SQL directly.
- Shape each query for its consumer: joins, aggregates, filters, authorization scope, and pagination.
- Queries return read models or response DTOs. They never return Active Record models.
- Queries do not write. `ApplicationQuery` runs `perform` in `ActiveRecord::Base.while_preventing_writes`, in a read-only transaction. A query inside a command joins the command's transaction, so that transaction is not read-only.
- A query can call other queries, but not commands.

```ruby
Enrollments::RosterQuery.call(school_id:, page:)
```

## Auditing

- An audit event records who changed what, and when. It is a row in `audit_events` (capability `Auditing`).
- An event has:
  - the actor: a user (`actor_user_id`), or an operator for operations work (`operator_reference`, for example "Ops: Avery Lin, ticket ONB-42"). A check constraint requires exactly one.
  - the action, as `<subject>.<past-tense verb>`, for example `school_administrator.role_changed`;
  - the subject (`subject_type`, `subject_id`);
  - the changed attributes (`details`), as `{ "attribute" => [before, after] }`;
  - the time (`created_at`).
- Record an event with `Auditing::RecordEvent`.
- Audit events are append-only. `db/privileges.sql` revokes `UPDATE` and `DELETE` from the app role. Reason: the app cannot change history.
- A command writes its audit record in its own transaction. Reason: the audit record and the change commit or roll back together.
- Queries stay read-only. The caller (for example, a controller) records an audited read after the query returns. It calls an audit command. Reason: an audit record is a side effect of the request, not of the query.
- Record audited reads synchronously, in the database. Do not record them through a job. Reason: an enqueue is also a database write, so a job gives no gain. A synchronous write also lets a read fail when its audit record cannot be written.
- Record denied reads as well as successful reads.
- If audit records must go to an external system, write them to the database first. Then send them with a job.

## Loading data

- `strict_loading_by_default` is on. Reason: loading stays explicit, and N+1 queries raise errors.
- Load associations explicitly with `includes`, `preload`, or `eager_load`.

## Results and errors

- `UseCaseResult` is a success (`UseCaseResult::Success`) or a failure (`UseCaseResult::Failure`).
- A success contains a value: an ID, a small outcome payload, or a response DTO. `success(nil)` is a success with no value.
- A failure contains errors and a category. It has no value. `failure.value` raises `UseCaseResult::NoValueError`.
- Response DTOs are `T::Struct`s.
- `Api::V1::BaseController` maps failure categories to HTTP statuses:

  | Category | Meaning | HTTP status |
  | --- | --- | --- |
  | `validation` | Input is not valid, or a business rule rejects it | 422 |
  | `unauthenticated` | The person is not logged in, or login failed | 401 |
  | `forbidden` | The actor has no permission | 403 |
  | `not_found` | A record is not found | 404 |
  | `conflict` | A concurrent change or a duplicate | 409 |

- Bugs and infrastructure failures raise exceptions. The API returns 500.
- All failures use one error format:

  ```json
  { "errors": [{ "field": "email", "code": "invalid", "message": "is not a valid email address" }] }
  ```

  `field` is `null` when an error is not about one field.

## Responses

- The serializer renders the value in the result.
- API responses are response DTOs. They are never Active Record models. Reason: the API shape stays separate from the database structure.

## Validation

| Where | What |
| --- | --- |
| React | User-facing checks for fast feedback. The server does not trust them. |
| Command and query inputs | Shape and format: presence, types, formats, lengths |
| Models and policies | Business rules and invariants |
| Database | Always: NOT NULL, foreign keys, unique indexes, check constraints |


## Transactions

- Commands own transactions.
- `ApplicationCommand` runs each command in `ApplicationRecord.transaction`.
- Rails joins a transaction that is already open. So the outermost command commits, and composed commands run in the same transaction.
- A command that returns a failure rolls back. `ApplicationCommand` raises `ActiveRecord::Rollback` to do this.
- `ActiveRecord::Rollback` has an effect only at the outermost level. An inner command cannot roll back alone.
- When a composed command fails, the caller must also return a failure.
- To recover from a failed inner command, run it in a savepoint (`requires_new: true`). Otherwise its partial writes are committed with the outer command.

## Dependencies

- We do not use a DI framework.
- A command or query declares a dependency with `dependency :name, type: SomeClass, default: -> { ... }`.
- Production code uses the defaults. Tests pass fakes to `call`, for example `call(inputs, push_gateway: fake)`.
- A dependency's value must be of its `type`. Otherwise the reader raises `TypeError`. A fake subclasses the class, or includes the module that `type` names.
- Inject only boundaries: external service gateways and ID or token generators.

## Time

- We do not inject a clock. Reason: Rails and gems read `Time.now`, so a second clock can disagree with them.
- When "now" is a business input, make it an `as_of` attribute on the command or query.

  ```ruby
  attribute :as_of, :datetime, default: -> { Time.current }
  ```

- Use `as_of` for reminders, digests, deadlines, and history lookups (for example, "which school was the student at on this date").
- Tests control time with Rails time helpers (`travel_to`, `freeze_time`), or pass `as_of`.
- Postgres `now()` and `uuidv7()` use the database clock. Rails time helpers do not change them.

## Isolated domain models

Most capabilities use Active Record models for business rules. A capability can use a domain model that does not depend on persistence when it has complex interacting rules, state transitions, or calculations that Active Record makes hard to express.

In that capability:

1. Domain objects and policies do not depend on Active Record, HTTP, or external APIs.
2. Commands use repositories that the capability defines.
3. Repositories map between Active Record and domain objects.
4. Transaction scope, loading, and concurrency are explicit.
5. The command's public inputs and result do not change.

Do not add a repository for each table. Do not copy every model into a domain object. Add a boundary only when it makes a real business model simpler.

## Callbacks

- Do not use a callback unless it is extremely idiomatic. Reason: callbacks hide behaviour and cause action at a distance.
- If a callback makes a workflow or behaviour hard to understand, do not use it. Make the step explicit in the command.
- Permitted: `before_action` for authentication and request context, `normalizes`, and `dependent:` on records that own their children.
- A gem that uses model callbacks (for example, an audit gem) needs a team decision before we add it.

## Identifiers

- Application tables use UUIDv7 primary keys, made by Postgres's `uuidv7()`. Reason: users cannot guess other record IDs, and the IDs sort by creation time.

## Time zones

- Each school has an IANA time zone, for example `America/Toronto`.
- Calculate reminders, digests, and event times in the school's time zone.

## Database migrations

- Database changes do not need to be backwards compatible.
- You can edit existing migrations.
- These rules change when we go to production (see `todo.md`).

## API and frontend

- API endpoints are under `/api/v1`.
- Commands return IDs or small outcome payloads. React gets full data from queries.
- A command that takes a long time (for example, a board-wide send) returns `202 Accepted` with a status URL. React polls the status URL until the work is complete.

### Data refresh in React

- React uses TanStack Query for server data.
- Query keys start with the capability name. Example: `['enrollments', 'roster', schoolId]`.
- After a command succeeds, React invalidates the affected query keys. TanStack Query fetches them again.
- Use optimistic updates only for selected interactions where speed matters. Example: signing a permission slip.
- TanStack Query fetches data again when the window gets focus. Use polling where a screen needs fresher data.

## Testing

- Write tests first. Tests prove business behaviour.
- Test behaviour, not implementation.
- Test commands through business outcomes, including rejection and conflict cases.
- Use the real database to test constraints, transactions, and concurrency.
- Test rules in policies and isolated domain models directly, without the database where possible.
- When a capability has repositories, test their mappings against the real database.
- Use request specs for API workflows from end to end.
- Every query has a tenant isolation test: it returns no rows from another organization. Isolation tests run as the app database role. Reason: the table owner is not subject to RLS, so a test as the owner proves nothing.
- Use browser tests for important React workflows.
- Use fakes only at injected boundaries.
- Tools:
  - Backend: RSpec, FactoryBot, and Rails time helpers (`travel_to`, `freeze_time`).
  - Frontend: Vitest and Testing Library.
  - Browser: Playwright (`frontend/e2e/*.e2e.ts`). Browser tests run against the real API and the development database with demo data.
  - Email: request and command specs check `ActionMailer::Base.deliveries`. Browser tests read the mail that the real API sent from Mailpit (`frontend/e2e/support/mailpit.ts`). Reason: a browser test proves the whole journey, including delivery over SMTP.
  - Network blocking, mutation, and property-based tools are in `todo.md`.
- The full guidelines are in `docs/guidelines/testing.txt`.

## Types

We use Sorbet with tapioca. Signatures are `sig { }` blocks. Reason: Sorbet finds type errors before the tests run.

| Files | Sigil |
| --- | --- |
| `app/`, `lib/`, `sorbet/tapioca/compilers/` | `# typed: strict` |
| `config/` | `# typed: strict`. A file that a DSL evaluates (`puma.rb`, `ci.rb`, `initializers/cors.rb`) is `# typed: false`. |
| `spec/` | `# typed: false`, and Sorbet ignores the directory (`sorbet/config`). Reason: Sorbet cannot type RSpec example groups, and a method that a spec defines in a block must not hide a missing method in app code. |

- rubocop-sorbet enforces the sigils.
- sorbet-runtime checks every signature when the code runs, in all environments. A value of the wrong type raises `TypeError`.
- `bin/srb tc` checks the types.

### RBI files

- `sorbet/rbi/` contains RBI files that tapioca generates. Commit them. Do not edit them.
- Put hand-written RBI files in `sorbet/rbi/shims/`.
- Regenerate the RBI files after these changes:

  | Change | Run |
  | --- | --- |
  | `Gemfile.lock` | `bin/tapioca gem` |
  | A migration, a model, a command or query, or `app/lib/use_case.rb` | `bin/tapioca dsl` |

- `bin/tapioca dsl` loads the app in the test environment, with eager loading, and reads the test database (`sorbet/tapioca/config.yml`). Run `bin/rails db:test:prepare` first. Reason: CI has only the test database, and eager loading makes the RBI files the same locally and in CI.
- CI runs `bin/tapioca gem --verify` and `bin/tapioca dsl --verify`. They fail when an RBI file is out of date.

### Commands and queries

- Tapioca types `attribute` readers and writers from the Active Model type. Example: `attribute :name, :string` gives `T.nilable(String)`.
- Our tapioca compiler (`sorbet/tapioca/compilers/use_case.rb`) generates the rest for each command and query:
  - a reader for each dependency, of the dependency's `type`;
  - `call`, which returns the type from the `perform` signature.
- So every `perform` has a signature, for example `sig { override.returns(UseCaseResult[Started]) }`.
- `UseCaseResult[Value]` is covariant. A `UseCaseResult::Failure` is a result of every value type.
- To read the value, check for a failure with `is_a?(UseCaseResult::Failure)` first. Sorbet then knows that the result is a success. `failure?` does not narrow the type.

### Escape hatches

- Do not use `T.untyped` or `T.unsafe` in `app/` or `lib/`. RuboCop rejects them.
- Use `T.must`, `T.cast` or `T.bind` only when a value has a type that Sorbet cannot prove. Add a comment that gives the reason.
- Rails methods without signatures return `T.untyped`. A signature or `T.let` gives the value a type at the boundary, and sorbet-runtime checks it.

## Shared guidelines

- `docs/guidelines/` contains copies of files from the useful_prompts repo. That repo is the source of truth.
- Do not edit the copies. Change the source, then run `bin/sync-guidelines`.
- `bin/sync-guidelines --check` tells you if the copies are out of date.
- The files are `workflow.txt`, `coding.txt`, `testing.txt`, and `language.txt`. `CLAUDE.md` says what each one covers.

## Background jobs

We use Solid Queue. Its tables are in the primary database. Reason: a job is committed or rolled back with the data that enqueues it, so it works as an outbox.

- Use Active Job only. Jobs inherit from `ApplicationJob`. Do not reference `SolidQueue::*` classes or tables in app code. Reason: the backend can change without code changes.
- A job calls a command with its arguments.
- Commands enqueue jobs with `perform_later` or `perform_all_later` in the command's transaction.
- Do not enqueue jobs from models or callbacks.
- Keep `enqueue_after_transaction_commit` set to `false`. If it is `true`, jobs are enqueued after commit, so a job and its data are no longer committed together.
- Specs check enqueued jobs with `have_enqueued_job`.
- Jobs that touch tenant data take `organization_id` as an argument.
- For a large send (for example, a board-wide notification), use `perform_all_later` in batches. Make one job for each recipient and channel.
- Define recurring jobs only in `config/recurring.yml`.
- Use Solid Queue-specific features (`limits_concurrency`, batches) only when necessary. Add a comment that gives the reason.
- Queues:

  | Queue | Use for |
  | --- | --- |
  | `critical` | Time-sensitive, user-facing work. Example: "the bus is late" push notifications. |
  | `default` | Most work. |
  | `low` | Digests and cleanup. |
