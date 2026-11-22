# Permishly

A communications portal for schools, parents, teachers and students. See `etc/overview.txt` for product notes.

## Layout

```
backend/            Rails 8.1 API (Ruby 4.0), PostgreSQL, Solid Queue, RSpec
frontend/           React 19 + TypeScript (Vite), React Router, TanStack Query, Tailwind, Vitest
docker-compose.yml  Local Postgres 18 and Mailpit
mise.toml           Pinned Ruby and Node versions
Procfile.dev        Processes started by bin/dev
architecture.md     Architecture rules
todo.md             Open decisions and pending work
docs/guidelines/    Synced copies of shared guidelines (do not edit; see bin/sync-guidelines)
docs/walkthroughs/  HTML tutorials that explain the code of a feature
```

## Prerequisites

- [mise](https://mise.jdx.dev): `brew install mise`, then add `eval "$(mise activate zsh)"` to `~/.zshrc`
- Docker (OrbStack or Docker Desktop)

## Getting started

```sh
bin/setup   # installs Ruby/Node, starts Postgres and Mailpit, installs deps, prepares the DB
bin/dev     # runs Postgres, Mailpit, Rails (:3000), Solid Queue workers and Vite (:5173)
```

Open http://localhost:5173. Vite proxies `/api` to Rails, so the browser talks to a single origin in development.

## Demo data

In development, `bin/rails db:seed` (and `db:prepare` on a new database) loads the school boards and schools from `etc/demo-school-data.txt`, with one administrator for each school. The password for every demo account is `permishly-demo`.

| Email | Administers |
| --- | --- |
| `marsha.deepwater@eldritch-shores.example` | Innsmouth Heights Secondary School |
| `prudence.form@central-directorate.example` | Compliance Collegiate |
| `gwendolyn.brightshield@united-realms.example` | Quest Preparatory Academy |
| `morgan.crossway@example.com` | Schools in two boards (shows the organization picker) |

The full list is in `backend/db/seeds/demo_data.rb`. In development, the login page also lists every board, school and login. Pick a login to fill in the form. The list comes from `GET /api/v1/development/demo_accounts`, which exists only in development and test.

## Email

In development, Rails sends mail over SMTP to Mailpit, which catches it. Nothing reaches a real inbox. See the mail at http://localhost:8025. Mail is sent by a job, so `bin/jobs` (part of `bin/dev`) must be running.

- RSpec does not use Mailpit. Mail goes to `ActionMailer::Base.deliveries` (the `:test` delivery method).
- Browser tests use Mailpit. The e2e Rails server runs jobs in Puma (`SOLID_QUEUE_IN_PUMA`). Read a message with `waitForEmail` from `frontend/e2e/support/mailpit.ts`. Use a recipient and a time, because development and the tests share one inbox.

## Common tasks

| Task                    | Command                                           |
| ----------------------- | ------------------------------------------------- |
| Backend tests           | `cd backend && bundle exec rspec`                 |
| Backend lint            | `cd backend && bin/rubocop`                       |
| Backend type check      | `cd backend && bin/srb tc`                        |
| Regenerate RBI files    | `cd backend && bin/tapioca gem` (after gem changes), `bin/tapioca dsl` (after migrations, models, commands and queries) |
| Backend security scan   | `cd backend && bin/brakeman && bin/bundler-audit` |
| Frontend tests          | `cd frontend && npm test`                         |
| Frontend lint / types   | `cd frontend && npm run lint && npm run typecheck`|
| Browser tests           | `cd frontend && npm run test:e2e` (starts its own Rails and Vite) |
| Sync guidelines         | `bin/sync-guidelines` (`--check` to verify)       |
| Stop services           | `docker compose down`                             |
| Wipe local data         | `docker compose down -v`                          |

## API conventions

- JSON endpoints live under `/api/v1` (`Api::V1::*` controllers inheriting `Api::V1::BaseController`).
- Health check: `GET /api/v1/health` (DB + job worker status); `GET /up` for load balancers.
- Background jobs use Active Job on Solid Queue, stored in the primary database. Read the job rules in `architecture.md` before writing a job. In development, restart `bin/dev` (or the `jobs` process) after adding a new job class; workers don't pick up new classes until restarted.
- Job dashboard (Mission Control): http://localhost:3000/jobs. It is open in development and uses HTTP basic auth elsewhere (`bin/rails mission_control:jobs:authentication:configure`).

## Configuration

The backend reads these env vars; the defaults match `docker-compose.yml`. Browser tests read `MAILPIT_URL` (default `http://localhost:8025`).

| Variable       | Default                    |
| -------------- | -------------------------- |
| `DB_HOST`      | `localhost`                |
| `DB_PORT`      | `5432`                     |
| `DB_USERNAME`  | `permishly` (owner role, for `db:` tasks) |
| `DB_PASSWORD`  | `permishly`                |
| `DB_APP_USERNAME` | `permishly_app` (app role, row-level security applies) |
| `DB_APP_PASSWORD` | `permishly_app`         |
| `CORS_ORIGINS` | `http://localhost:5173`    |
| `APP_URL`      | `http://localhost:5173` (the React app, for links in emails; production must set it) |
| `SMTP_HOST`    | `localhost` (development only) |
| `SMTP_PORT`    | `1025` (development only) |

In production, set `PRIMARY_DATABASE_URL` (app role) and `OWNER_DATABASE_URL` (owner role) instead. The database roles are described in `architecture.md`.

`pg_dump` writes `backend/db/structure.sql`. Its major version must be at least the server's (18): `brew install libpq` or `brew upgrade libpq`.
