# Agent conventions

Rails monolith. Stack and setup/run/test commands: [README.md](README.md) — don't duplicate them here.

## Architecture

- **Fat interactors, skinny everything else.** Business logic lives in `app/interactors/` (one interactor = one business action). Chain multi-step flows with an interactor organizer rather than one large interactor. Never write a one-line interactor that just wraps a single model call — that logic belongs directly in the model/controller.
- **Controllers**: params → interactor/model call → respond. No business logic in controllers.
- **Concerns, one per feature**: extract shared controller/model behavior into `app/controllers/concerns/` or `app/models/concerns/`, named after the feature it adds (e.g. `Archivable`, `TwoFactorAuthenticatable`), never a grab-bag `Shared` concern.
- **Authorization is never skipped.** Every controller action authorizes: `authorize record` for a single record, `policy_scope(Model)` for a collection. Add `after_action :verify_authorized` and `after_action :verify_policy_scoped, only: :index` once on `ApplicationController` so a missing check fails loudly by default, and use `skip_after_action` in a specific controller only where an action is genuinely public. `ApplicationController` already includes `Pundit::Authorization`.
- **API responses go through a serializer** — never build response hashes inline in a controller. Use Blueprinter (`blueprinter` gem, already in the Gemfile) as the default serializer for all JSON responses: one blueprint per resource in `app/blueprints/`, inheriting from `ApplicationBlueprint`, e.g. `render json: UserBlueprint.render(@user)`. Keep the shape of a resource defined in one place. Use Blueprinter *views* (`view :extended do ... end`, `render(@user, view: :extended)`) to vary a resource's fields for different purposes (e.g. a lean `:default` view for an index, a fuller view for `show` or an admin-only consumer) instead of writing a second blueprint class for the same resource. Blueprinter is configured (`config/initializers/blueprinter.rb`) to generate with `Oj` (already in the Gemfile) instead of the stdlib `JSON` generator.
- **Nest related resources with Blueprinter `association`** (`association :company, blueprint: CompanyBlueprint`), not by hand-nesting hashes or calling another blueprint's `.render` inline. An association can take its own `view:` (e.g. a summarized nested view). Because an association triggers its own reads, eager-load it in the controller (`includes(:company)`) before rendering a collection — Blueprinter won't do that for you, and an un-eager-loaded association is an N+1.
- **Every API endpoint gets an rswag request spec** (`spec/requests/**`) — it's both the test and the OpenAPI doc source. Regenerate docs with `bundle exec rake rswag:specs:swaggerize`; served at `/api-docs`.
- DRY, SRP, SOLID. Prefer deleting/simplifying over adding a new abstraction.

## Authentication & 2FA

- Use the Rails 8 built-in generator (`bin/rails generate authentication`) for email/password auth. Do not add Devise or another auth gem.
- Add TOTP 2FA with `rotp` only when a feature actually needs it, on top of the generated `User`/`Session`. Encrypt the stored `otp_secret` with Active Record Encryption (`encrypts :otp_secret`).

## UI

- Tailwind CSS + Heroicons (`heroicon` gem) only — no other CSS framework or icon set.

## Testing

- No test may make a real network call to a third party. Every external service (payment processor, mail API, etc.) must be stubbed. `webmock`/`vcr` aren't in the Gemfile yet — add one before writing a spec that touches an external HTTP client.
- Policies get their own specs using `pundit-matchers` (already in the Gemfile).
- Use FactoryBot + Faker for test data, not fixtures.
- Request specs double as API docs via rswag (see Architecture above).
- E2E flows through the UI (not covered by request specs) go in `e2e/` as Playwright tests.

## Code quality

- A change isn't done until `bin/rubocop`, `bin/brakeman`, and `bin/bundler-audit` (see README) are clean. Fix what they flag; don't silence a cop/warning inline or in `.rubocop.yml` without a comment explaining why it's a false positive here.
- `npm run lint:js` (ESLint, flat config in `eslint.config.mjs`) lints `app/javascript/**/*.js`. The app ships JS via import maps with no build step, so the config is bundler-free (no import-resolution plugin) — just `eslint:recommended` plus browser globals.

## Agent skills

### Issue tracker

Issues live as GitHub issues in this repo, managed via the `gh` CLI (`gh` infers the repo from `git remote -v`). See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout: `CONTEXT.md` + `docs/adr/` at the repo root (created lazily as needed). See `docs/agents/domain.md`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
