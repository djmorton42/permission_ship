# Permishly

- Architecture rules: `architecture.md`. Open decisions and pending work: `todo.md`. Setup and commands: `README.md`.
- Writing style for docs and replies: `docs/guidelines/language.txt`. Testing rules: `docs/guidelines/testing.txt`.
- Make changes on a branch, and merge them to `main` through a pull request. Do not commit to `main` unless the user says so for that change. Start the branch from an up-to-date `main`.
- Never push without explicit permission from the user for that push. Permission for one push does not cover later pushes. This includes pushing a branch and opening a pull request.
- Run Ruby and Node through mise, for example `mise exec -- bundle exec rspec`. Reason: the shell may not have the pinned versions.

## Checks during development

Run the checks after every change, before you report the work as done. Report failures with their output.

| You changed | Run |
| --- | --- |
| Ruby code | `cd backend && bundle exec rspec` and `bin/rubocop` |
| Migrations | Also `bin/rails db:migrate` and `bin/rails db:test:prepare`, and commit `db/structure.sql` |
| TypeScript code | `cd frontend && npx vitest run`, `npm run typecheck` and `npm run lint` |
| A user journey (for example login) | Also `cd frontend && npm run test:e2e` |

CI (`.github/workflows/ci.yml`) runs all of these on every push.
