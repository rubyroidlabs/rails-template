# frozen_string_literal: true

# Base class for all API serializers. Every resource blueprint inherits from
# this one so shared behavior (views, transformers, etc.) has a single home.
class ApplicationBlueprint < Blueprinter::Base
end
