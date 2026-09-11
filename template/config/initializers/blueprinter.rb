# frozen_string_literal: true

# Blueprinter's own `Oj.generate` calls lazily trigger this on first use anyway;
# calling it eagerly avoids Oj's "called implicitly" runtime warning.
Oj::Rails.mimic_JSON

Blueprinter.configure do |config|
  # Use Oj instead of the stdlib JSON generator (already in the Gemfile).
  config.generator = Oj

  # Render timestamps as ISO 8601, matching Rails' own JSON encoding of Time/DateTime.
  config.datetime_format = ->(datetime) { datetime&.iso8601 }
end
