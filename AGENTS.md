# Bootstrapping a project with this template

You are an agent setting up a new Rails application from `rubyroidlabs/rails-template`. Follow this end to end; don't improvise a different sequence.

If you are instead **changing the template itself**, skip to [Working on the template](#working-on-the-template).

## 1. Check the environment before generating anything

```bash
ruby -v     # must be >= 4.0
rails -v    # must be >= 8.0
docker --version
node -v
```

The template aborts on Ruby < 4.0 or Rails < 8.0. If `rails` is missing or too old, install it (`gem install rails`) rather than working around the version check.

## 2. Generate the app

Ask the user for the application name if they haven't given one. Use `snake_case` — it becomes the Ruby module name, the database names and the Postgres role.

```bash
rails new <app_name> \
  --database=postgresql \
  --css=tailwind \
  --skip-test \
  --skip-action-cable \
  -m https://raw.githubusercontent.com/rubyroidlabs/rails-template/main/template.rb
```

All four flags matter. PostgreSQL and Tailwind are enforced; `--skip-test` keeps RSpec as the only test suite and `--skip-action-cable` matches the rest of the setup. Don't add `--api`, `--skip-git`, `--skip-bundle` or a different asset pipeline — the template is written against this exact shape.

This takes a few minutes (bundle install, importmap, Tailwind, Kamal, Solid*). Let it finish; don't interrupt and retry.

## 3. Verify before touching anything

```bash
cd <app_name>
docker compose up -d              # Postgres + MailHog
bin/rails db:prepare
bundle exec rspec                 # 2 examples, 0 failures
bin/rubocop                       # clean
```

If `bundle exec rspec` can't reach the database, wait for the Postgres healthcheck (`docker compose ps`) and retry — don't start editing `config/database.yml`.

For the browser suite, install Chromium once:

```bash
npm install
npx playwright install --with-deps chromium
npm run test:e2e                  # 1 passed
```

Report the results of these commands to the user. Do not report the setup as done until RSpec and RuboCop are green.

## 4. Finish the repo setup

1. **Credentials.** `rails new` already generated a fresh `config/master.key` and `config/credentials.yml.enc`. The key is gitignored. Tell the user to store it in their password manager — it is the only copy, and Kamal reads it via `.kamal/secrets`. Never print it into a file that is tracked, a commit message, or a PR.
2. **Remote.** Create the GitHub repo and push `main` only when the user asks. The template's CI workflow runs on `main` and on pull requests.
3. **Deployment.** `config/deploy.yml` is the stock Kamal file with placeholder hosts and registry. Leave it alone until the user has real infrastructure.
4. **Agent tooling.** `rails new` already ran `bin/setup-agents`; check its output for skipped steps (it needs uv or pipx for graphify, Node.js for the skills installer, and the `claude` CLI for the plugin) and re-run it once the missing tool is installed. Then run `/graphify` once so agents have a knowledge graph to query — `graphify-out/` is gitignored, so the graph is rebuilt per clone, not committed.

## 5. Read the conventions before writing any code

`AGENTS.md` in the generated app is the engineering contract. Read it in full before the first feature. The rules that are easiest to violate by accident:

- Business logic goes in `app/interactors/`, not in controllers or fat models.
- Every controller action authorizes — `authorize record` or `policy_scope(Model)`. `ApplicationPolicy` denies by default.
- JSON responses go through a Blueprinter blueprint in `app/blueprints/`, never an inline hash.
- Every API endpoint gets an rswag request spec; it is both the test and the OpenAPI source.
- No test may make a real third-party network call.
- A change isn't done until `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit` and `npm run lint:js` are clean.

`README.md` has the commands. `docs/agents/` has the issue-tracker and domain-doc conventions.

## What the template deliberately leaves out

Don't add these speculatively; add them when a feature needs them.

- **Authentication** — use Rails' own generator when it's needed: `bin/rails generate authentication`. Do not add Devise.
- **HTTP stubbing** — `webmock` or `vcr` are not in the Gemfile. Add one before writing the first spec that touches an external HTTP client.
- **A root route** — the app has none. `/up`, `/api-docs` and the Playwright suite all use the health check.
- **`CONTEXT.md` and `docs/adr/`** — created lazily by `/grill-with-docs` when real terms and decisions emerge, not upfront.

## Working on the template

The repository is a Rails application template, not a Rails app. `template.rb` is the only file `rails new` downloads; it shallow-clones the repo to reach `template/`.

- Files under `template/` are copied verbatim, except `.tt` files, which are rendered as ERB with the generator's context (`app_name` is the underscored app name).
- Runtime ERB inside a `.tt` file must be escaped as `<%%= ... %>` so it reaches the generated app unevaluated. `template/config/database.yml.tt` is the example.
- Agent skills are **not** vendored under `template/`. `template/bin/setup-agents` installs them in the generated app with each tool's own installer (`claude plugin install`, `npx skills add`, `graphify install`), and `template.rb` runs it in `after_bundle`. Add tooling by extending that script, not by copying skill files into the repo. Set `SKIP_AGENT_SETUP=1` to generate an app without it.
- Patches to files Rails itself generates (`config/routes.rb`, `app/controllers/application_controller.rb`, `.gitignore`, …) use `inject_into_file` against anchors in the Rails-generated content. Thor inserts verbatim, so use the `indented` helper — a squiggly heredoc alone will land at column 0.
- `source_paths` keeps Rails' own paths after ours; `rails new` still resolves its own templates after this file has been applied.

Always test a change by generating an app end to end, not by reading the diff:

```bash
rails new /tmp/scratch/demo_app --database=postgresql --css=tailwind \
  --skip-test --skip-action-cable -m ./template.rb
```

Never commit a `config/master.key`, a `config/credentials.yml.enc`, or anything else from a generated app into this repository.
