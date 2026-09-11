# Rubyroid Labs Rails template

A [Rails application template](https://guides.rubyonrails.org/rails_application_templates.html) for building Rails monoliths **with AI agents** — Claude Code, Cursor, Codex and friends — rather than alongside them.

`rails new` gives you a great skeleton. This adds the parts an agent needs to be productive on day one: an opinionated architecture with written-down conventions, an authorization layer that fails loudly when you forget it, API docs generated from the test suite, a real test pyramid (RSpec + Playwright), and agent harness configuration that is checked into the repo instead of living in someone's home directory.

## Usage

```bash
rails new myapp \
  --database=postgresql \
  --css=tailwind \
  --skip-test \
  --skip-action-cable \
  -m https://raw.githubusercontent.com/rubyroidlabs/rails-template/main/template.rb
```

Then:

```bash
cd myapp
docker compose up -d   # Postgres + MailHog
bin/setup              # gems, database, dev server
```

Requires **Ruby >= 4.0** and **Rails >= 8.0** — the template checks both and stops early if they aren't met. It does not pin either any further, so you always get the newest Rails you have installed.

PostgreSQL and Tailwind are required (`config/database.yml`, `docker-compose.yml`, the CI workflow and the UI conventions are all written against them); the template refuses to run without those two flags. `--skip-test` and `--skip-action-cable` are recommended rather than required — if a Minitest `test/` tree slips through, the template removes it so the app has exactly one test suite.

To run it from a local checkout instead of GitHub:

```bash
git clone https://github.com/rubyroidlabs/rails-template.git
rails new myapp --database=postgresql --css=tailwind --skip-test --skip-action-cable \
  -m rails-template/template.rb
```

`RAILS_TEMPLATE_REPO` and `RAILS_TEMPLATE_BRANCH` override where the template fetches its files from when run by URL — useful for testing a branch.

## What you get

### Based on

Vanilla `rails new` on Rails 8 — Propshaft, import maps, Hotwire (Turbo + Stimulus), Solid Queue, Solid Cache, Kamal, Thruster, Brakeman, bundler-audit and RuboCop Omakase all stay exactly as Rails ships them. Everything below is layered on top.

### Architecture

| | |
|---|---|
| **Pundit** | Authorization. `ApplicationController` includes `Pundit::Authorization` and rescues `NotAuthorizedError`; `ApplicationPolicy` denies by default. |
| **Interactor** | Business logic in `app/interactors/`, one interactor per business action, organizers for multi-step flows. |
| **Blueprinter + Oj** | JSON serialization. One blueprint per resource in `app/blueprints/`, never inline hashes in controllers. |
| **Heroicon** | Icons, paired with Tailwind. No second icon set or CSS framework. |

### Testing & API docs

| | |
|---|---|
| **RSpec** | Replaces Minitest. `rails_helper` already wires up FactoryBot syntax methods, `pundit-matchers` and `spec/support/**`. |
| **FactoryBot + Faker** | Test data. No fixtures. |
| **rswag** | Request specs double as the OpenAPI source. `bundle exec rake rswag:specs:swaggerize` regenerates `swagger/v1/swagger.yaml`; Swagger UI is mounted at `/api-docs`. |
| **Playwright** | End-to-end browser tests in `e2e/`, with a TypeScript config that boots its own Rails server on port 3100. |
| **ESLint** | Flat config for the Stimulus controllers in `app/javascript`. Bundler-free, matching the import-map setup. |

A health-check request spec, rswag spec and Playwright spec ship as working examples of each layer.

### Local environment

`docker-compose.yml` runs PostgreSQL 18 and [MailHog](https://github.com/mailhog/MailHog). Development mail is delivered to MailHog over SMTP and readable at `http://localhost:8025`, so nothing escapes to a real inbox. `config/database.yml` reads `DATABASE_{HOST,PORT,USERNAME,PASSWORD}` so the same file works locally and in CI.

### CI

`.github/workflows/ci.yml` runs five jobs: Ruby security scans (Brakeman + bundler-audit), an import-map audit, lint (RuboCop with a warm cache + ESLint), RSpec, and Playwright with its report uploaded on failure. `bin/ci` runs the equivalent pipeline locally from `config/ci.rb`.

### Agent setup

This is the part `rails new` doesn't give you.

- **`AGENTS.md`** — the engineering contract: architecture rules, the authorization invariant, serialization rules, testing rules, and the definition of done. Agents read it; so should humans.
- **`CLAUDE.md`**, **`.claude/`**, **`.codex/`**, **`.cursor/`** — harness configuration for Claude Code, Codex and Cursor, checked into the repo so every contributor and every agent gets the same setup.
- **[mattpocock/skills](https://github.com/mattpocock/skills)** — vendored under `.agents/skills/` and pinned in `skills-lock.json`, plus enabled as a Claude Code plugin. Gives you `/implement`, `/code-review`, `/research`, `/grill-with-docs` and the rest as first-class workflows instead of ad-hoc prompting.
- **graphify** — a knowledge-graph skill vendored for all three harnesses, with hooks that push agents to query the graph before grepping. Run `/graphify` once in the new repo to build it; `graphify-out/` is gitignored.
- **`docs/agents/`** — how agents should use the issue tracker (GitHub issues via `gh`) and the domain docs (`CONTEXT.md` + `docs/adr/`, created lazily).

### Credentials

Nothing secret is in this repo. Every generated app gets its own `config/master.key` and `config/credentials.yml.enc` straight from `rails new`; the key is gitignored and never leaves your machine.

## Repository layout

```
template.rb          the application template — the only file rails new downloads
template/            everything copied into the generated app
  AGENTS.md          engineering conventions for the new app
  .agents/ .claude/ .codex/ .cursor/   vendored skills + harness config
  spec/ e2e/ swagger/                  test suites and generated API docs
  *.tt                                 ERB templates interpolating the app name
AGENTS.md            instructions for an agent bootstrapping a project with this template
```

When the template is run by URL, `template.rb` shallow-clones this repository to a temp directory so it can copy `template/`, then cleans up after itself.

## Working on the template

Try a change end to end before pushing it:

```bash
rails new /tmp/scratch/demo_app --database=postgresql --css=tailwind \
  --skip-test --skip-action-cable -m ./template.rb
```

Files under `template/` are copied verbatim unless they end in `.tt`, which are ERB templates rendered with the generator's context — `app_name` is the underscored application name. Runtime ERB inside a `.tt` file (for example in `config/database.yml.tt`) must be escaped as `<%%= ... %>` so it survives to the generated app.

## License

MIT — see [LICENSE](LICENSE).
