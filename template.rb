# frozen_string_literal: true

# Rubyroid Labs AI-native Rails template.
#
#   rails new myapp \
#     --database=postgresql \
#     --css=tailwind \
#     --skip-test \
#     --skip-action-cable \
#     -m https://raw.githubusercontent.com/rubyroidlabs/rails-template/main/template.rb
#
# See README.md in https://github.com/rubyroidlabs/rails-template for the full story.

require "fileutils"
require "tmpdir"

REPO_URL    = ENV.fetch("RAILS_TEMPLATE_REPO", "https://github.com/rubyroidlabs/rails-template.git")
REPO_BRANCH = ENV.fetch("RAILS_TEMPLATE_BRANCH", "main")

MIN_RUBY_VERSION  = "4.0"
MIN_RAILS_VERSION = "8.0"

# ---------------------------------------------------------------------------
# Source files
# ---------------------------------------------------------------------------

# `rails new -m <url>` downloads only this file, so when we're run from a URL we
# need the rest of the repo (everything under template/) fetched separately.
def template_root
  @template_root ||=
    if __FILE__.match?(%r{\Ahttps?://})
      dir = Dir.mktmpdir("rubyroidlabs-rails-template-")
      say_status :fetch, "#{REPO_URL} (#{REPO_BRANCH})", :green
      unless system("git", "clone", "--quiet", "--depth", "1", "--branch", REPO_BRANCH, REPO_URL, dir)
        raise Thor::Error, "Could not clone #{REPO_URL} (branch #{REPO_BRANCH})."
      end
      at_exit { FileUtils.remove_entry(dir, true) }
      dir
    else
      File.expand_path(File.dirname(__FILE__))
    end
end

# Ours first so our README.md.tt wins over Rails' own, but keep Rails' paths:
# `rails new` still resolves templates of its own (.kamal/secrets, for one)
# after this file has been applied.
def source_paths
  [ File.join(template_root, "template"), *(defined?(super) ? super : []) ]
end

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

def check_versions!
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(MIN_RUBY_VERSION)
    raise Thor::Error, "This template needs Ruby >= #{MIN_RUBY_VERSION} (running #{RUBY_VERSION})."
  end

  if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new(MIN_RAILS_VERSION)
    raise Thor::Error, "This template needs Rails >= #{MIN_RAILS_VERSION} (running #{Rails::VERSION::STRING})."
  end
end

def check_generator_options!
  problems = []
  problems << "--database=postgresql" unless options[:database].to_s == "postgresql"
  problems << "--css=tailwind"        unless options[:css].to_s == "tailwind"
  return if problems.empty?

  raise Thor::Error, <<~MSG
    This template assumes PostgreSQL and Tailwind (config/database.yml, docker-compose.yml,
    the CI workflow and the UI conventions are all written against them). Re-run with:

      rails new #{app_name} \\
        --database=postgresql \\
        --css=tailwind \\
        --skip-test \\
        --skip-action-cable \\
        -m #{__FILE__}

    Missing: #{problems.join(" ")}
  MSG
end

# ---------------------------------------------------------------------------
# Gemfile
# ---------------------------------------------------------------------------

# Thor's `inject_into_file` inserts verbatim, so squiggly heredocs need their
# indentation put back before they land inside a block or a class body.
def indented(text, spaces)
  text.gsub(/^(?=.)/, " " * spaces)
end

# `inject_into_file` silently no-ops when the anchor is gone (a future Rails
# could reword the generated Gemfile), so fall back to appending.
def add_to_gemfile(content, after:, indent: 0)
  if File.read("Gemfile").match?(after)
    inject_into_file "Gemfile", indented(content, indent), after: after, verbose: false
  else
    append_to_file "Gemfile", "\n#{content}", verbose: false
  end
end

def configure_gemfile
  # Blueprinter replaces jbuilder as the serialization layer.
  gsub_file "Gemfile", /^#\s*Build JSON APIs.*\ngem "jbuilder".*\n/, "", verbose: false
  gsub_file "Gemfile", /^gem "jbuilder".*\n/, "", verbose: false

  add_to_gemfile(<<~RUBY, after: /^gem "tailwindcss-rails".*\n/)
    # Fast, declarative JSON serializer for API responses [https://github.com/procore-oss/blueprinter]
    gem "blueprinter"
    # Fast JSON generator, used as Blueprinter's JSON backend [https://github.com/ohler55/oj]
    gem "oj"
    # Rails view helpers for Heroicons SVG icons [https://github.com/bharget/heroicon]
    gem "heroicon"
  RUBY

  add_to_gemfile(<<~RUBY, after: /^gem "image_processing".*\n/)

    # Minimal authorization through OO design and pure Ruby classes [https://github.com/varvet/pundit]
    gem "pundit"

    # Service objects with a common interface [https://github.com/collectiveidea/interactor-rails]
    gem "interactor-rails"

    # Generate OpenAPI docs from request specs and serve them with Swagger UI [https://github.com/rswag/rswag]
    gem "rswag-api"
    gem "rswag-ui"
  RUBY

  add_to_gemfile(<<~RUBY, after: /^\s*gem "rubocop-rails-omakase".*\n/, indent: 2)

    # RSpec for unit/model/request specs [https://github.com/rspec/rspec-rails]
    gem "rspec-rails"

    # RSpec matchers for testing Pundit authorization policies [https://github.com/punditrb/pundit-matchers]
    gem "pundit-matchers"

    # Generate OpenAPI docs from RSpec request specs [https://github.com/rswag/rswag]
    gem "rswag-specs"

    # Test data factories [https://github.com/thoughtbot/factory_bot_rails]
    gem "factory_bot_rails"

    # Fake data for factories [https://github.com/faker-ruby/faker]
    gem "faker"

    gem "ruby-lsp-rspec"
  RUBY
end

# ---------------------------------------------------------------------------
# Application code
# ---------------------------------------------------------------------------

def copy_application_files
  # RSpec: our own spec_helper/rails_helper rather than `rspec:install`, so the
  # FactoryBot, Pundit matchers and support-file wiring is already in place.
  copy_file ".rspec"
  directory "spec"

  # Pundit
  copy_file "app/policies/application_policy.rb"

  # Interactor
  keep_file "app/interactors"

  # Blueprinter + Oj
  copy_file "app/blueprints/application_blueprint.rb"
  copy_file "config/initializers/blueprinter.rb"

  # Heroicons
  copy_file "app/helpers/heroicon_helper.rb"
  copy_file "config/initializers/heroicon.rb"

  # rswag / OpenAPI
  copy_file "config/initializers/rswag_api.rb"
  copy_file "config/initializers/rswag_ui.rb"
  directory "swagger"

  # Local services + CI
  template "docker-compose.yml.tt", "docker-compose.yml"
  template "config/database.yml.tt", "config/database.yml", force: true
  template ".github/workflows/ci.yml.tt", ".github/workflows/ci.yml", force: true

  # Playwright + ESLint
  template "package.json.tt", "package.json", force: true
  copy_file "playwright.config.ts"
  copy_file "tsconfig.json"
  copy_file "eslint.config.mjs"
  directory "e2e"

  # Docs
  template "README.md.tt", "README.md", force: true
  copy_file "AGENTS.md"
  copy_file "CLAUDE.md"
  directory "docs"

  # Agent tooling installs itself (see `run_agent_setup`); the template only
  # copies the script that drives it. Everything the skills and graphify
  # installers write — .agents/skills, .claude, .codex, .cursor,
  # skills-lock.json — is generated in the new app rather than vendored here.
  copy_file "bin/setup-agents"
  chmod "bin/setup-agents", 0o755, verbose: false
end

def patch_generated_files
  # Pundit
  inject_into_class "app/controllers/application_controller.rb", "ApplicationController",
                    indented("include Pundit::Authorization\n\n", 2)

  inject_into_file "app/controllers/application_controller.rb", before: /^end\s*\z/ do
    indented(<<~RUBY, 2)

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_back fallback_location: "/"
      end
    RUBY
  end

  # rswag mounts
  inject_into_file "config/routes.rb", after: /Rails\.application\.routes\.draw do\n/ do
    indented(<<~RUBY, 2)
      # Serves the generated OpenAPI docs (swagger/v1/swagger.yaml) and the Swagger UI at /api-docs
      mount Rswag::Ui::Engine => "/api-docs"
      mount Rswag::Api::Engine => "/api-docs"

    RUBY
  end

  # MailHog in development
  inject_into_file "config/environments/development.rb",
                   after: /config\.action_mailer\.default_url_options = .*\n/ do
    indented(<<~RUBY, 2)

      # Deliver emails to MailHog (see docker-compose.yml) so they can be viewed
      # at http://localhost:8025 instead of being sent for real.
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.smtp_settings = {
        address: "localhost",
        port: 1025
      }
    RUBY
  end

  # bin/ci
  inject_into_file "config/ci.rb", after: /step "Style: Ruby".*\n/ do
    %(  step "Style: JavaScript", "npm run lint:js"\n)
  end

  # `--skip-test` is recommended but not enforced; drop the Minitest tree if it
  # slipped through so there's exactly one test suite (spec/).
  remove_dir "test" if File.directory?("test")
end

def keep_file(dir)
  empty_directory dir
  create_file File.join(dir, ".keep"), "", verbose: false
end

# The skills and graphify installers need network access and tools we don't
# control (uv/pipx, npx, the Claude Code CLI). The script reports and skips
# whatever is missing, and can be re-run by hand, so a failure here is a
# warning rather than a dead `rails new`.
def run_agent_setup
  if ENV["SKIP_AGENT_SETUP"]
    say_status :skip, "agent tooling (SKIP_AGENT_SETUP set) — run bin/setup-agents later", :yellow
    return
  end

  say_status :agents, "installing skills and graphify", :green
  return if run("bin/setup-agents", capture: false, abort_on_failure: false)

  say_status :warn, "bin/setup-agents did not finish — re-run it by hand", :yellow
end

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

check_versions!
check_generator_options!

configure_gemfile
copy_application_files
patch_generated_files

after_bundle do
  # Appended here rather than earlier so these land after the entries the
  # Tailwind and importmap installers add during `rails new`.
  append_to_file ".gitignore", <<~IGNORE

    # Node / Playwright
    /node_modules
    /playwright-report
    /test-results
    /blob-report
    /playwright/.cache

    # Graphify knowledge graph
    /graphify-out

    # Local, per-developer agent settings
    /.claude/settings.local.json
  IGNORE

  if File.exist?("package.json") && system("which npm > /dev/null 2>&1")
    say_status :npm, "installing JavaScript dev dependencies", :green
    run "npm install"
  else
    say_status :skip, "npm not found — run `npm install` before using Playwright/ESLint", :yellow
  end

  run_agent_setup

  say <<~DONE

    ------------------------------------------------------------------------
    #{app_name} is ready.

      cd #{app_name}
      docker compose up -d      # Postgres + MailHog
      bin/setup                 # gems, database, dev server

    Agent tooling (skills + graphify) is installed by bin/setup-agents; re-run
    it any time to upgrade, and after cloning this repo somewhere new.

    Then read AGENTS.md — it's the contract every agent and human follows here.
    ------------------------------------------------------------------------
  DONE
end
