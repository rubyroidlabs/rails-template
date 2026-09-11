require "swagger_helper"

RSpec.describe "Health", type: :request do
  path "/up" do
    get "Checks application health" do
      tags "Health"
      produces "text/html"

      response "200", "application boots with no exceptions" do
        run_test!
      end
    end
  end
end
