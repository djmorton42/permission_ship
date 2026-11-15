# Rails Backend

Architecture rules for the backend. Open decisions and pending work are in `todo.md`.

## Layers

We use onion architecture. Dependencies point inward only. An inner layer never references an outer layer.

| Layer | Contains | Depends on |
| --- | --- | --- |
| Delivery (outermost) | Controllers (`Api::V1::*`), jobs, rake tasks | Application |
| Application | Commands, queries, request DTOs, response DTOs, `UseCaseResult` | Domain; repositories and gateways (injected) |
| Domain (innermost) | Entities, value objects, domain rules (plain Ruby) | Nothing outside the domain |
| Infrastructure | Repositories, ActiveRecord models, gateways (push, email, SMS, payments), task scheduler | Domain. The task scheduler also references job classes. |

- ActiveRecord models are for persistence only. They stay in infrastructure.
- Repositories take and return domain objects, never AR models.
- Repositories do not open transactions.
- The domain layer does not know about Rails, HTTP, jobs, or the database.

### Loading data

- Repositories return fully loaded domain objects. There is no lazy loading.
- Each repository method loads the associations its use case needs. Example: `find_student` and `find_student_with_guardians` are separate methods.
- Access to an association that was not loaded is a bug. Reason: data access stays explicit and N+1 queries cannot occur.

## Commands and queries

- Every action is a command or a query. Commands change state. Queries do not change state.
- A workflow usually maps to one command or query.
- A command or query can compose finer-grained commands or queries. A query can call queries, but not commands.
- Each command and query has `execute(request)`. It takes a request DTO and returns a `UseCaseResult`.
- A command can return data, for example the ID of a created record or a response DTO.

### Command pipeline

Every command does these steps in this order:

1. Call `validate` on the request. If the request is not valid, return a failure.
2. Open a transaction (see Transactions).
3. Load data through repositories. Authorize the actor. (The authorization design is in `todo.md`.)
4. Do the domain and workflow validation.
5. Do the workflow.

Steps 3 to 5 run in one transaction. A domain check that protects a write must use a row lock or a database constraint. Example: "Is there space on the field trip?" Reason: two concurrent requests can both pass a check that only reads.

## Requests (input DTOs)

- Every command and query takes a request object, for all HTTP verbs.
- Query requests contain IDs, filters, and pagination.
- Name a request for its use case, not for its endpoint. Example: `EnrollStudentRequest`. Reason: jobs and other commands also make requests.
- Requests do not depend on HTTP.
- Controllers make requests from `params`. Requests declare their attributes and ignore other params, so we do not use strong params.
- Requests use `ActiveModel::Model` and `ActiveModel::Attributes` for type casting and validation.
- `validate` returns a `ValidationResult`.

## Results and errors

- A `UseCaseResult` is a success or a failure.
- A success contains a value. The value is a response DTO.
- A failure contains errors and a category.
- `Api::V1::BaseController` maps failure categories to HTTP statuses:

  | Category | HTTP status |
  | --- | --- |
  | `validation` | 422 |
  | `forbidden` | 403 |
  | `not_found` | 404 |
  | `conflict` | 409 |

- Expected business outcomes are failure results. Examples: input is not valid, the actor has no permission, a record is not found, a business rule is not met.
- Bugs and infrastructure failures raise exceptions.
- All failures use one error format, including `ValidationResult` errors:

  ```json
  { "errors": [{ "field": "email", "code": "invalid", "message": "is not a valid email address" }] }
  ```

  `field` is `null` when an error is not about one field.

## Responses (output DTOs)

- The serializer renders the value in the result.
- The value is a response DTO. It is never a domain entity or an AR model. Reason: the API shape stays separate from internal models.

## Validation

| Where | What |
| --- | --- |
| Request | Shape and format: presence, types, formats, lengths |
| Command and domain | Business rules: uniqueness in context, state changes, eligibility |
| AR model | Little or nothing |
| Database | Always: NOT NULL, foreign keys, unique indexes, check constraints |

Database constraints are the last line of defense.

## Transactions

- The application layer owns transactions.
- Each command runs its steps in `ApplicationRecord.transaction`.
- Rails joins a transaction that is already open. So the outermost command commits, and composed commands run in the same transaction.
- A command that returns a failure rolls back. The base command raises `ActiveRecord::Rollback` to do this.
- `ActiveRecord::Rollback` has an effect only at the outermost level. An inner command cannot roll back alone.
- When a composed command fails, the caller must also return a failure.
- To recover from a failed inner command, run it in a savepoint (`requires_new: true`). Otherwise its partial writes are committed with the outer command.
- Queries do not write. We can enforce this with `ActiveRecord::Base.while_preventing_writes`.
- Do not call external services (payments, email, push) in a transaction. Schedule a job (see Background jobs).

## Dependencies

- We do not use a DI framework.
- Dependencies are constructor keyword arguments with production defaults. Example: `def initialize(push_gateway: PushGateway.new)`.
- Delivery code calls `.new`. Tests pass fakes.
- Inject only boundaries: external service gateways, the task scheduler, the clock, and ID or token generators. Do not inject pure code.

## Callbacks

- Do not use a callback unless it is extremely idiomatic. Reason: callbacks hide behaviour and cause action at a distance.
- If a callback makes a workflow or behaviour hard to understand, do not use it. Make the step explicit in the command.
- Permitted: `before_action` for authentication and request context, `normalizes`, and `dependent:` on records that own their children.
- A gem that uses model callbacks (for example, an audit gem) needs a team decision before we add it.

## Identifiers

- Application tables use UUIDv7 primary keys, made by Postgres's `uuidv7()`. Reason: users cannot guess other record IDs, and the IDs sort by creation time.

## Time zones

- Store all times in UTC.
- Each school has an IANA time zone, for example `America/Toronto`.
- Calculate reminders, digests, and event times in the school's time zone.

## Database migrations

- Database changes do not need to be backwards compatible.
- You can edit existing migrations.
- These rules change when we go to production (see `todo.md`).

## Testing

- Write tests first. Tests prove business behaviour.
- Test behaviour, not implementation.
- Use request specs for API workflows from end to end.
- Use unit specs for requests, domain rules, and commands.
- Use fakes only at injected boundaries.
- Tools:
  - Backend: RSpec, FactoryBot, and Rails time helpers (`travel_to`, `freeze_time`).
  - Frontend: Vitest and Testing Library.
  - Network blocking, browser, mutation, and property-based tools are in `todo.md`.
- The full guidelines are in `docs/guidelines/testing.txt`.

## Shared guidelines

- `docs/guidelines/` contains copies of files from the useful_prompts repo. That repo is the source of truth.
- Do not edit the copies. Change the source, then run `bin/sync-guidelines`.
- `bin/sync-guidelines --check` tells you if the copies are out of date.
- `docs/guidelines/language.txt` sets the writing style for docs.

## Background jobs

We use Solid Queue. Its tables are in the primary database. Reason: a job is committed or rolled back with the data that schedules it.

- Use Active Job only. Jobs inherit from `ApplicationJob`. Do not reference `SolidQueue::*` classes or tables in app code. Reason: the backend can change without code changes.
- A job is a thin delivery adapter. It makes a request from its arguments and calls a command. It contains no business logic.
- Commands schedule jobs through an injected task scheduler. Example: `task_scheduler.send_notification(notification_id)`. Reason: commands must not reference job classes in the delivery layer.
- The default task scheduler is in infrastructure. It calls `perform_later` or `perform_all_later`.
- Tests inject a fake task scheduler and assert what was scheduled.
- Schedule jobs in the command's transaction. Do not schedule jobs from models or callbacks.
- Keep `enqueue_after_transaction_commit` set to `false`. If it is `true`, jobs are enqueued after commit, so a job and its data are no longer committed together.
- Every job must be idempotent. It must be safe to run two times.
- Every job must handle a record that is missing or changed. Check the state again before you act.
- Pass only IDs and primitive values to jobs. Do not pass AR models or large payloads.
- For a large send (for example, a board-wide notification), use `perform_all_later` in batches. Make one job for each recipient and channel.
- Define recurring jobs only in `config/recurring.yml`.
- Use Solid Queue-specific features (`limits_concurrency`, batches) only when necessary. Add a comment that gives the reason.
- Queues:

  | Queue | Use for |
  | --- | --- |
  | `critical` | Time-sensitive, user-facing work. Example: "the bus is late" push notifications. |
  | `default` | Most work. |
  | `low` | Digests and cleanup. |
