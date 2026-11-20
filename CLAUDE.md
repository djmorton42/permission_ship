# Permishly

- Architecture rules: `architecture.md`. Open decisions and pending work: `todo.md`. Setup and commands: `README.md`.
- Writing style for docs and replies: `docs/guidelines/language.txt`. Testing rules: `docs/guidelines/testing.txt`.
- Make functional changes (code, database schema, build system, CI) on a branch, and merge them to `main` through a pull request. Start the branch from an up-to-date `main`.
- Commit changes to docs about what we build or how we build it (for example `architecture.md`, `todo.md`, `CLAUDE.md`) directly to `main`.
- Never push without explicit permission from the user for that push. Permission for one push does not cover later pushes. This includes pushing a branch and opening a pull request.
- Build features as simply as possible. If an edge case is not likely to happen, do not add code for it. Tell the user about it: how likely it is, what happens if it occurs, and what handling it would cost. The user decides.
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
