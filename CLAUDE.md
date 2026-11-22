# Permishly

- Shared guidelines are in `docs/guidelines/`. Follow them:
  - `workflow.txt`: branches, pushing, checks, and project docs.
  - `coding.txt`: simple code, explicit behaviour, data integrity, jobs, and time.
  - `testing.txt`: testing rules.
  - `language.txt`: writing style for docs and replies.
- Architecture rules: `architecture.md`. Open decisions and pending work: `todo.md`. Setup and commands: `README.md`.
- Run Ruby and Node through mise, for example `mise exec -- bundle exec rspec`. Reason: the shell may not have the pinned versions.

## Checks during development

| You changed | Run |
| --- | --- |
| Ruby code | `cd backend && bundle exec rspec`, `bin/rubocop` and `bin/srb tc` |
| Migrations | Also `bin/rails db:migrate`, `bin/rails db:test:prepare` and `bin/tapioca dsl`, and commit `db/structure.sql` and `sorbet/rbi/dsl/` |
| Models, commands, queries or `app/lib/use_case.rb` | Also `bin/tapioca dsl`, and commit `sorbet/rbi/dsl/` |
| Gems (`Gemfile.lock`) | Also `bin/tapioca gem`, and commit `sorbet/rbi/gems/` |
| TypeScript code | `cd frontend && npx vitest run`, `npm run typecheck` and `npm run lint` |
| A user journey (for example login) | Also `cd frontend && npm run test:e2e` |

CI (`.github/workflows/ci.yml`) runs all of these for each pull request and on each push to `main`.
